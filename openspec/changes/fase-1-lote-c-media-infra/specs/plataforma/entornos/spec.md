## ADDED Requirements
### Requirement: Entornos separados y revisables
La infraestructura SHALL definir entornos dev, staging y prod sin incluir valores secretos en el repositorio.
#### Scenario: Validación local
- **WHEN** se valida la configuración de infraestructura
- **THEN** no se despliegan recursos ni se generan cargos
#### Scenario: Producción
- **WHEN** se propone producción
- **THEN** la configuración exige secretos externos, almacenamiento privado y límites de escalado
