# Spec Delta

## MODIFIED Requirements

### Requirement: Solo el asignado recibe el detalle

Para uso operativo, el detalle de un pedido de ayuda SHALL sincronizarse solo bajo demanda para el coordinador o brigadista con asignación activa al caso. El autor SHALL poder consultar su propio historial mediante un flujo privado separado. Ningún stream de suscripción automática MUST incluir datos sensibles.

#### Scenario: Vecino no asignado intenta suscribirse

- **WHEN** un celular sin asignación se suscribe al stream del caso con su `pedido_id`
- **THEN** no recibe ninguna fila del caso

#### Scenario: Brigadista asignado

- **WHEN** el brigadista asignado se suscribe al stream del caso
- **THEN** recibe el detalle del pedido y nada de otros casos
- **AND** recibe solo la precisión de ubicación permitida para la etapa actual

## ADDED Requirements

### Requirement: Precisión de ubicación por etapa

Para el brigadista asignado, la ubicación SHALL ser aproximada al aceptar el caso. La ubicación exacta SHALL llegar en un flujo separado y solo durante el estado «En camino», con la asignación activa.

#### Scenario: El brigadista acepta el caso y luego sale en camino

- **WHEN** el brigadista acepta el caso y solicita el flujo de ubicación exacta antes de pasar a «En camino»
- **THEN** recibe la ubicación aproximada y el flujo exacto devuelve cero filas
- **AND** al pasar a «En camino» puede recibir la ubicación exacta mientras conserve la asignación

#### Scenario: Termina el tramo autorizado

- **WHEN** el caso deja de estar «En camino» o termina la asignación
- **THEN** el flujo exacto deja de entregar la ubicación y la copia desaparece en la siguiente sincronización

### Requirement: Auditoría de apertura de datos sensibles

El backend SHALL registrar quién accedió, cuándo y a qué caso por cada apertura operativa autorizada. El registro MUST NOT incluir el contenido sensible abierto.

#### Scenario: Se abre el detalle de un caso asignado

- **WHEN** el coordinador o brigadista abre el detalle autorizado de un caso
- **THEN** queda un registro de acceso con actor, fecha y caso, sin ubicación, datos de salud ni descripción del pedido
