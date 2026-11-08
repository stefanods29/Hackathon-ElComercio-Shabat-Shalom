## ADDED Requirements
### Requirement: Compartir contenido público confirmado
La app SHALL abrir el selector del teléfono únicamente con contenido público confirmado y enlaces permitidos.
#### Scenario: Publicación local pendiente
- **WHEN** se intenta compartir una publicación que todavía no está enviada
- **THEN** la app explica que primero debe enviarse y no abre el selector
#### Scenario: Cancelación
- **WHEN** el vecino cancela el selector
- **THEN** la app no afirma que se compartió
