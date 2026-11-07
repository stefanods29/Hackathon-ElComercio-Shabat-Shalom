# Spec Delta

## Purpose

Garantizar que los reintentos de la cola offline del celular nunca ejecuten dos veces la misma acción ni creen duplicados (sección 3.4).

## ADDED Requirements

### Requirement: Clave obligatoria en las escrituras
Toda escritura que el celular envía desde su cola SHALL exigir la cabecera `Idempotency-Key` (8 a 255 caracteres ASCII visibles; se recomienda un UUIDv7) y MUST responder 400 si falta.

#### Scenario: Escritura sin clave
- **WHEN** el celular envía `POST /v1/publicaciones` sin `Idempotency-Key`
- **THEN** la API responde 400 y no ejecuta la acción

### Requirement: Reintento con la misma clave
Un reintento con la misma clave, el mismo usuario y el mismo contenido SHALL devolver la respuesta guardada sin volver a ejecutar la acción: 200 con `Idempotent-Replayed: true` si fue un éxito, o el mismo rechazo si fue un 4xx definitivo.

#### Scenario: El celular no recibió la respuesta y reintenta
- **WHEN** el celular repite `POST /v1/publicaciones` con la misma clave y el mismo cuerpo
- **THEN** la API responde 200 con la misma publicación y la cabecera `Idempotent-Replayed: true`
- **AND** en la base sigue existiendo una sola publicación

### Requirement: Reintentos concurrentes
Si llegan varias solicitudes con la misma clave a la vez, la API SHALL ejecutar la acción una sola vez y MUST responder 409 `solicitud_en_curso` con `Retry-After` a las demás.

#### Scenario: Diez reintentos simultáneos
- **WHEN** llegan diez solicitudes con la misma clave al mismo tiempo
- **THEN** exactamente una ejecuta la acción y las otras reciben 409 `solicitud_en_curso`

### Requirement: Clave reutilizada con otro contenido
La API SHALL rechazar con 422 `idempotency_key_reutilizada` una clave ya usada por el mismo usuario con otro método, ruta o cuerpo.

#### Scenario: Misma clave, otro cuerpo
- **WHEN** el celular reutiliza una clave con un título distinto
- **THEN** la API responde 422 y no ejecuta la acción

### Requirement: Fallos transitorios liberan la clave
Ante un error 5xx, 408 o 429 la API SHALL liberar la clave para que el reintento vuelva a ejecutar la acción. Una reserva en curso abandonada por más de 60 segundos MUST poder retomarse.

#### Scenario: Falla de la base de datos
- **WHEN** la primera ejecución falla con 500 y el celular reintenta con la misma clave
- **THEN** la acción se ejecuta de nuevo y responde según su resultado
