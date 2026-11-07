# Spec Delta

## Purpose

Comprobar con una prueba de carga reproducible que la arquitectura soporta el pico de una emergencia (sección 5.6 y 13.1).

## ADDED Requirements

### Requirement: Escenario de pico de emergencia reproducible
El repositorio SHALL incluir un escenario k6 que simule unas 2 500 peticiones por segundo durante 10 minutos, con la mezcla de lecturas, escrituras idempotentes y reconexión simultánea de clientes de sincronización.

#### Scenario: Ejecución del escenario
- **WHEN** el equipo corre el escenario contra un entorno de staging
- **THEN** obtiene un informe con latencia p95, tasa de error y profundidad de la cola crítica

### Requirement: Umbrales de aceptación
La prueba SHALL fallar si la latencia p95 o la tasa de error superan los umbrales acordados, o si la cola crítica se degrada.

#### Scenario: Regresión de rendimiento
- **WHEN** un cambio sube la latencia p95 por encima del umbral
- **THEN** el escenario k6 termina con error y el informe lo señala

### Requirement: Correlación sin datos sensibles
La API SHALL devolver `x-request-id` y correlacionarlo con logs JSON y con el `instance` y
`requestId` de Problem Details. Los logs MUST NOT incluir cuerpos, tokens ni consultas de URL.

#### Scenario: Rechazo guardado y repetido
- **WHEN** se repite una escritura cuyo rechazo fue guardado por idempotencia
- **THEN** el rechazo conserva su contenido funcional y usa el requestId de la solicitud actual

### Requirement: Métricas operativas protegidas
La API SHALL reservar las métricas para administradores e incluir los cuatro resultados de
idempotencia, pendientes y edad del outbox, y profundidad actual de cada cola. Los contadores
de proceso MUST indicar su instancia e inicio y las colas MUST reflejar el motor real.

#### Scenario: Vecino consulta métricas
- **WHEN** un vecino sin rol administrador consulta `/v1/operacion/metricas`
- **THEN** recibe 403 y no obtiene datos operativos

### Requirement: Humo verificable y alcance de la evidencia
El repositorio SHALL incluir un humo local con API y workers separados, sesiones sintéticas
revocables y pg-boss real, más controles que demuestren el rechazo por latencia y cola crítica.
El informe MUST distinguir el humo local de una certificación de capacidad en staging.

#### Scenario: No hay staging disponible
- **WHEN** el equipo ejecuta únicamente el humo local
- **THEN** el informe muestra sus métricas y mantiene explícitamente pendiente la validación del pico completo
