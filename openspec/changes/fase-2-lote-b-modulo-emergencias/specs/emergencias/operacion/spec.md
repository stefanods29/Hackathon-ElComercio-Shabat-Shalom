## ADDED Requirements

### Requirement: Cobertura explícita
El sistema SHALL aceptar pedidos solamente con evento activo, dos coordinadores habilitados y
al menos uno de turno; la activación del modo por sí sola no promete atención.

#### Scenario: Zona sin coordinación suficiente
- **WHEN** un vecino envía un pedido sin cobertura vigente
- **THEN** recibe 409 `zona_sin_cobertura` y la acción alternativa de abrir el directorio oficial

### Requirement: Turnos y grupos verificados
El sistema SHALL rechazar turnos superpuestos y reservar la verificación de grupos a administración.

#### Scenario: Se termina un turno vigente
- **WHEN** el coordinador finaliza el turno con su versión actual
- **THEN** las asignaciones correspondientes dejan de autorizar el acceso privado

### Requirement: Alertas oficiales configuradas
El sistema SHALL consultar solo un feed explícitamente configurado, con límites, reintentos,
circuit breaker y deduplicación por fuente, referencia y zona.

#### Scenario: No existe un canal aprobado
- **WHEN** no se configura la URL del feed
- **THEN** no se realizan consultas ni se inventa una integración con organismos oficiales
