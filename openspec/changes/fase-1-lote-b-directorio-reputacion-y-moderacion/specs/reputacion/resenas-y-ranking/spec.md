# Spec Delta

## Purpose

Que los vecinos califiquen y reseñen los servicios de su zona, den su Visto Bueno y vean un ranking
justo que no se pueda inflar con trampas ni con reintentos (sección 5.5 de la arquitectura).

## ADDED Requirements

### Requirement: Escribir una reseña
`POST /v1/resenas` SHALL registrar una reseña con un id UUIDv7 del celular, calificación de 1 a 5,
comentario opcional de hasta 2 000 caracteres y hasta 3 fotos por `archivoId`. Entra "en revisión"
junto con su evento, en la misma transacción.

#### Scenario: Reseña válida
- **WHEN** un vecino de nivel 1 califica con 5 un servicio de su zona
- **THEN** la API responde 201 con la reseña en estado `en_revision` y registra `reputacion.resena_creada`

#### Scenario: Reintento con el mismo id
- **WHEN** el celular reenvía la misma reseña
- **THEN** la API responde 200 y sigue existiendo una sola reseña

### Requirement: Una reseña por vecino y servicio
Un vecino SHALL tener como máximo una reseña por servicio; una segunda MUST responder 409
`resena_duplicada`.

#### Scenario: Segunda reseña
- **WHEN** un vecino que ya reseñó un servicio envía otra reseña con un id nuevo
- **THEN** la API responde 409 `resena_duplicada`

### Requirement: Nadie se reseña a sí mismo
El dueño de un servicio MUST NOT poder reseñarlo ni darle Visto Bueno: la API responde 403
`no_puedes_resenarte`.

#### Scenario: Proveedor que se reseña
- **WHEN** un proveedor intenta reseñar su propio servicio
- **THEN** la API responde 403 `no_puedes_resenarte`

### Requirement: Fotos solo con la reseña publicada
Las fotos de una reseña SHALL enlazarse a archivos del propio autor y MUST NOT ser públicas antes de
que la reseña se publique.

#### Scenario: Foto ajena
- **WHEN** la reseña enlaza un `archivoId` de otro vecino
- **THEN** la API responde 422 `archivo_no_valido`

### Requirement: Visto Bueno
`POST` y `DELETE /v1/servicios/{id}/visto-bueno` SHALL dar y quitar el Visto Bueno del vecino, uno
por vecino y servicio, de forma idempotente. Solo el de un vecino de nivel 2 o más MUST contar para
el ranking.

#### Scenario: Visto Bueno repetido
- **WHEN** el celular repite el Visto Bueno que ya dio
- **THEN** la API responde 200 y el servicio sigue teniendo uno solo de ese vecino

#### Scenario: Vecino de nivel 1
- **WHEN** un vecino de nivel 1 da su Visto Bueno
- **THEN** queda registrado pero no suma a los Visto Bueno de vecinos verificados

### Requirement: Ranking bayesiano desde los hechos
Un trabajo SHALL recalcular el total de reseñas, el promedio, el puntaje bayesiano y los Visto Bueno
de un servicio a partir de todas sus reseñas publicadas y Visto Bueno vigentes, nunca sumando
incrementos, de modo que un reintento no lo descuadre.

#### Scenario: Trabajo entregado dos veces
- **WHEN** el recálculo de un servicio se ejecuta dos veces seguidas
- **THEN** el puntaje es el mismo que el calculado a mano con la fórmula de la sección 5.5

#### Scenario: Una sola reseña de 5 estrellas
- **WHEN** un servicio tiene una reseña de 5 y otro de la misma categoría tiene 80 reseñas con promedio 4,8
- **THEN** el segundo queda por encima en el ranking

### Requirement: Antifraude básico
La API SHALL exigir una antigüedad mínima de la cuenta para reseñar, limitar las reseñas por día y
enviar a moderación los patrones dudosos, como muchas reseñas desde el mismo dispositivo.

#### Scenario: Cuenta recién creada
- **WHEN** una cuenta con menos de la antigüedad mínima intenta reseñar
- **THEN** la API responde 403 `cuenta_muy_nueva`

#### Scenario: Límite diario
- **WHEN** un vecino supera el límite diario de reseñas
- **THEN** la API responde 429 `limite_diario_alcanzado` con `Retry-After`

### Requirement: Solo servicios de la zona
Un vecino SHALL reseñar y dar Visto Bueno solo a servicios de su zona; fuera de ella la API MUST
responder 403 `fuera_de_tu_zona`.

#### Scenario: Servicio de la zona vecina
- **WHEN** un vecino de la zona piloto intenta reseñar un servicio de la zona vecina
- **THEN** la API responde 403 `fuera_de_tu_zona`
