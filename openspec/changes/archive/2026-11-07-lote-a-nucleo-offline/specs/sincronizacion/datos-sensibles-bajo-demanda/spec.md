# Spec Delta

## Purpose

Validar en la Fase 0 el mecanismo de la sección 8: el detalle sensible de un caso llega únicamente al celular de quien lo tiene asignado y se borra cuando deja de estarlo.

## ADDED Requirements

### Requirement: Solo el asignado recibe el detalle
El detalle de un pedido de ayuda SHALL sincronizarse solo mediante un stream bajo demanda, al que se suscribe el celular del brigadista o coordinador asignado a ese caso. Ningún stream de suscripción automática MUST incluir datos sensibles.

#### Scenario: Vecino no asignado intenta suscribirse
- **WHEN** un celular sin asignación se suscribe al stream del caso con su `pedido_id`
- **THEN** no recibe ninguna fila del caso

#### Scenario: Brigadista asignado
- **WHEN** el brigadista asignado se suscribe al stream del caso
- **THEN** recibe el detalle del pedido y nada de otros casos

### Requirement: Revocación en línea
Cuando termina una asignación, las filas del caso SHALL dejar de pertenecer al stream del usuario y MUST borrarse de su celular en la siguiente sincronización.

#### Scenario: Se reasigna el caso
- **WHEN** el coordinador reasigna el caso a otro brigadista y el primero sincroniza
- **THEN** el detalle desaparece del celular del primero

### Requirement: Prueba de acceso automatizada
La configuración de Sync Streams SHALL tener pruebas automatizadas de acceso que fallen si un usuario no autorizado puede recibir filas sensibles.

#### Scenario: Cambio peligroso en la configuración
- **WHEN** alguien agrega un stream automático que lee `emergencias.pedidos_ayuda`
- **THEN** las pruebas de acceso fallan en CI
