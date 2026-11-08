# Spec Delta

## MODIFIED Requirements

### Requirement: Caducidad local de datos sensibles

Los datos sensibles SHALL borrarse del celular en cuanto la app conozca el cierre del caso o al vencer el plazo local, incluso sin señal. Para el autor podrá conservarse solo el historial personal mínimo autorizado, cifrado y sin el detalle sensible que deba purgarse.

#### Scenario: Plazo vencido sin señal

- **WHEN** vence la caducidad de un caso y el celular no tiene conexión
- **THEN** la app borra el detalle sensible al abrirse o en su siguiente revisión periódica
- **AND** al reabrir la app, el detalle vencido no aparece antes de la purga

#### Scenario: El cierre se conoce al reconectar

- **WHEN** la app recibe el cierre de un caso que había quedado descargado
- **THEN** elimina el detalle operativo y sensible del dispositivo
- **AND** el autor puede ver solo el estado final, su hora y el motivo apto para su historial
