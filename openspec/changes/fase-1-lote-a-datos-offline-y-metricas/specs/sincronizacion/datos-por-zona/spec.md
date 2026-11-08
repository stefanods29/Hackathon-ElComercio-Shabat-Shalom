# Spec Delta

## MODIFIED Requirements

### Requirement: Publicaciones eliminadas
Una publicación con borrado lógico o ocultada por moderación SHALL dejar de pertenecer a los streams y desaparecer de los celulares en la siguiente sincronización. Si la moderación la restaura, MUST volver a llegar a los celulares de su zona.

#### Scenario: Publicación retirada por moderación
- **WHEN** se marca `eliminado_en` en una publicación
- **THEN** los celulares la borran de su base local al sincronizar

#### Scenario: Publicación ocultada por moderación
- **WHEN** un moderador oculta una publicación del muro
- **THEN** los celulares de la zona la borran de su base local en la siguiente sincronización

#### Scenario: Publicación restaurada
- **WHEN** un moderador restaura una publicación que había ocultado
- **THEN** vuelve a aparecer en el muro de los vecinos de su zona
