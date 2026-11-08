## ADDED Requirements
### Requirement: Monitoreo técnico mínimo
El sistema SHALL excluir texto de vecinos, tokens, ubicaciones y cuerpos de solicitudes de la telemetría.
#### Scenario: Error con información personal
- **WHEN** ocurre un error con una solicitud autenticada
- **THEN** el reporte conserva solo clasificación técnica y contexto permitido
#### Scenario: Monitoreo desactivado
- **WHEN** no se configuran exportadores ni Sentry
- **THEN** backend y app funcionan sin conectarse a esos servicios
