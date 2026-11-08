# Spec Delta

## Purpose

Que el equipo vea durante el piloto cómo funcionan la API, los workers, las colas, la sincronización
y la app, y se entere de una falla antes que los vecinos, sin datos personales (sección 11 de la
arquitectura).

## ADDED Requirements

### Requirement: Trazas de punta a punta
El backend SHALL emitir trazas, métricas y logs con OpenTelemetry, de modo que una solicitud se pueda
seguir por la API, la base de datos y el worker que procesa su evento.

#### Scenario: Publicar en el muro
- **WHEN** un vecino publica en el muro
- **THEN** una misma traza muestra la solicitud HTTP, la transacción y el trabajo del outbox

### Requirement: Errores sin datos personales
Los errores del backend y de la app SHALL enviarse a Sentry después de limpiar teléfonos, nombres,
contenido, ubicaciones, tokens y cuerpos de solicitudes.

#### Scenario: Error de prueba
- **WHEN** se provoca un error de prueba con un teléfono en el mensaje
- **THEN** el evento llega a Sentry con el teléfono reemplazado y sin el cuerpo de la solicitud

### Requirement: Tableros del piloto
El equipo SHALL tener tableros de sincronización (métricas del Lote A), de operación
(`GET /v1/operacion/metricas`) y de colas, actualizados a partir de los datos del entorno.

#### Scenario: Celular de prueba
- **WHEN** un celular de prueba envía sus métricas de sincronización
- **THEN** el tablero de sincronización muestra su envío en el resumen del día

### Requirement: Alertas básicas
El sistema SHALL alertar al equipo cuando la cola crítica se detiene o cuando los errores aumentan por
encima del umbral acordado.

#### Scenario: Cola crítica detenida
- **WHEN** hay trabajos críticos pendientes sin procesarse durante más del umbral
- **THEN** el equipo recibe una alerta con el nombre de la cola y su antigüedad
