## ADDED Requirements

### Requirement: Identidad estable y estados válidos
El sistema SHALL aceptar pedidos desde nivel cero con ID del teléfono e Idempotency-Key.
SHALL aplicar la máquina `enviado → visto → en_camino → atendido`, con derivación o cierre con
motivo desde `visto`; el solicitante confirma la atención.

#### Scenario: Otro operador cambió el pedido
- **WHEN** llega una modificación con una versión anterior
- **THEN** se rechaza con 409 `conflicto_de_version` sin aplicar el cambio

#### Scenario: La persona asignada inicia su recorrido
- **WHEN** un brigadista vigente y de turno cambia un caso visto a `en_camino`
- **THEN** la transición queda auditada y su lectura privada puede incluir la ubicación exacta

### Requirement: Escalamiento recuperable
El sistema SHALL conservar plazos y etapas en PostgreSQL, programar trabajos críticos y
recuperar trabajos omitidos mediante un barrido. Reintentar una misma etapa MUST NOT repetirla.

#### Scenario: Nadie revisó el pedido
- **WHEN** vence su plazo y continúa enviado
- **THEN** se busca otro coordinador de turno o una zona de apoyo acordada y se avisa al vecino
  sin atribuir atención humana; tras tres etapas se detiene el escalamiento automático
