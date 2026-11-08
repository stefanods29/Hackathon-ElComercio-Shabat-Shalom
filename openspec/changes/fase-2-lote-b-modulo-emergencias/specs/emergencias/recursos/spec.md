## ADDED Requirements

### Requirement: Evidencia y frescura separadas
El sistema SHALL mostrar fecha y umbral del reporte, exigir confirmaciones independientes y
reservar la verificación a roles habilitados. Solo administración puede acreditar una fuente oficial.

#### Scenario: Cambia la cantidad de un recurso
- **WHEN** el reportante o un operador autorizado actualiza el stock con la versión actual
- **THEN** se renueva el reporte y se retiran las confirmaciones y la verificación anteriores

#### Scenario: El mismo vecino confirma dos veces
- **WHEN** se reintenta su confirmación
- **THEN** no aumenta el número de confirmaciones independientes

### Requirement: Agregados con supresión
El sistema SHALL publicar únicamente conteos de al menos tres pedidos por celda y necesidad,
sin identidades, descripciones, coordenadas exactas ni totales que permitan completar valores omitidos.

#### Scenario: Hay menos de tres pedidos
- **WHEN** el worker genera la instantánea pública
- **THEN** esa combinación no tiene fila ni conteo; ausencia no significa cero
