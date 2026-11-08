## ADDED Requirements

### Requirement: Habilitación y auditoría
El sistema SHALL exigir revisión humana de DNI, capacitación, confidencialidad y vigencia para
habilitar roles operativos; MUST NOT recibir imágenes del documento en estas rutas.

#### Scenario: Una persona ajena solicita el detalle
- **WHEN** no es solicitante ni tiene una asignación y habilitación vigentes
- **THEN** no recibe el detalle ni la ubicación del pedido

#### Scenario: Lectura autorizada
- **WHEN** un solicitante u operador asignado consulta datos privados
- **THEN** el sistema registra actor, rol, momento y caso antes de responder

### Requirement: Cierre y anonimización recuperables
El sistema SHALL retirar asignaciones al iniciar el cierre y anonimizar por lotes los casos,
conservando solo cifras y el rastro operativo sujeto a su política de retención.

#### Scenario: El worker se interrumpe
- **WHEN** quedan pedidos sin anonimizar en un evento en recuperación
- **THEN** la siguiente ejecución retoma el trabajo sin declarar el evento cerrado antes de terminar
