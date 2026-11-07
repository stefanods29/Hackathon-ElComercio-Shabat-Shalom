# Spec Delta

## Purpose

Cada acción del vecino muestra en qué estado está y la app decide, con las mismas reglas que el servidor, si reintentar o dar el envío por rechazado (sección 3.4).

## ADDED Requirements

### Requirement: Estados visibles de cada envío
Toda acción hecha en el celular SHALL estar en uno de tres estados visibles: "Guardado en tu celular" (nadie más lo recibió), "Enviado" (el servidor lo guardó) o "No se pudo completar" (rechazo definitivo con motivo). Cada estado MUST mostrarse con texto e ícono, no solo con color.

#### Scenario: Publicar sin señal
- **WHEN** el vecino publica en modo avión
- **THEN** la publicación aparece al instante en su muro marcada "Guardado en tu celular"

### Requirement: Decisión de reintentar
La app SHALL tratar 2xx como enviado; 4xx salvo 408 y 429 como rechazo definitivo con el `codigo` y el `detail` del servidor; y la falta de red, 408, 429 y 5xx como fallo transitorio que se reintenta.

#### Scenario: Otro vecino tomó el favor
- **WHEN** el servidor responde 409 `favor_no_disponible`
- **THEN** la acción pasa a "No se pudo completar" con ese motivo y no se reintenta

#### Scenario: Servidor caído
- **WHEN** el servidor responde 503
- **THEN** la acción sigue "Guardado en tu celular" y se reintenta más tarde

### Requirement: Misma clave en todos los reintentos
Cada acción SHALL generar una única `Idempotency-Key` (UUIDv7) al crearse y MUST reutilizarla en todos sus reintentos.

#### Scenario: Tercer reintento
- **WHEN** una acción se reintenta por tercera vez
- **THEN** envía la misma `Idempotency-Key` que en el primer intento

### Requirement: Reintentos escalonados
La espera antes de cada reintento SHALL crecer de forma exponencial desde 2 segundos hasta un máximo de 5 minutos, con una variación aleatoria entre cero y ese techo para que miles de celulares no reconecten a la vez.

#### Scenario: Vuelve la señal en todo el barrio
- **WHEN** cien celulares reintentan su quinto envío
- **THEN** sus esperas se reparten entre 0 y 32 segundos en lugar de coincidir
