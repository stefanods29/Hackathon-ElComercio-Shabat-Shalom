# Spec Delta

## Purpose

Muro de favores de la zona: los vecinos publican lo que ofrecen o necesitan y otro vecino toma el favor, sin duplicados aunque haya reintentos ni carreras entre celulares sin conexión.

## ADDED Requirements

### Requirement: Publicar en el muro
Un vecino con nivel de confianza 1 o más y una zona SHALL poder publicar un favor de tipo ofrezco, necesito, presto, dono, intercambio o movilidad, con título de 3 a 120 caracteres. El `id` MUST ser un UUIDv7 generado en el celular.

#### Scenario: Publicación válida
- **WHEN** un vecino nivel 1 publica "Presto taladro por la tarde"
- **THEN** la publicación queda abierta, en versión 1, en la zona del vecino

#### Scenario: Vecino recién registrado
- **WHEN** un vecino nivel 0 intenta publicar
- **THEN** la API responde 403 `nivel_de_confianza_insuficiente`

### Requirement: Sin duplicados por reintentos
Si llega una publicación con un `id` que ya existe del mismo autor, la API SHALL responder 200 con la publicación existente. Si el `id` es de otra persona, MUST responder 409 `id_en_uso` sin revelar su contenido.

#### Scenario: Reintento con otra clave de idempotencia
- **WHEN** el celular reenvía la misma publicación con una `Idempotency-Key` nueva
- **THEN** la API responde 200 y sigue existiendo una sola publicación

### Requirement: Ubicación aproximada
La ubicación de una publicación SHALL guardarse redondeada a unos 100 metros; la ubicación exacta MUST NOT almacenarse ni publicarse.

#### Scenario: Coordenadas precisas
- **WHEN** el celular envía lat -12.085678 y lng -77.034567
- **THEN** se guardan como -12.086 y -77.035

### Requirement: Tomar un favor
Un favor abierto SHALL poder tomarlo un solo vecino de la misma zona, distinto del autor, indicando la versión que veía. El servidor decide: el primero gana.

#### Scenario: Dos vecinos lo toman sin conexión
- **WHEN** Beto y Carla toman el mismo favor en versión 1 y Beto llega primero
- **THEN** Beto recibe 200 con el favor en curso y versión 2
- **AND** Carla recibe 409 `favor_no_disponible` con el estado actual

#### Scenario: La publicación cambió
- **WHEN** un vecino intenta tomar un favor abierto con una versión vieja
- **THEN** la API responde 409 `conflicto_de_version` con la versión esperada y la actual

#### Scenario: Reintento del ganador
- **WHEN** el celular de Beto repite la acción ya aceptada
- **THEN** la API responde 200 sin cambiar la versión

### Requirement: Eventos de dominio
Crear una publicación y tomar un favor SHALL registrar sus eventos (`solidaridad.publicacion_creada`, `solidaridad.favor_tomado`) en el outbox, en la misma transacción que el cambio.

#### Scenario: Falla al guardar
- **WHEN** la transacción de tomar el favor se revierte
- **THEN** tampoco queda el evento en el outbox
