# Spec Delta

## Purpose

Que todo contenido de los vecinos se pueda denunciar, que una persona con el rol de moderador lo
revise a tiempo y que lo ocultado salga del directorio, del muro y de los celulares (secciones 4.2,
4.3 y 9.1 de la arquitectura).

## ADDED Requirements

### Requirement: Denunciar contenido
`POST /v1/denuncias` SHALL registrar de forma idempotente la denuncia de una publicación, una reseña,
un servicio, una foto o un perfil de proveedor, con un motivo de una lista cerrada y un detalle
opcional de hasta 500 caracteres.

#### Scenario: Denuncia válida
- **WHEN** un vecino denuncia una reseña con el motivo `ofensivo`
- **THEN** la API responde 201 y la reseña queda con un caso pendiente de revisión

#### Scenario: Motivo fuera de la lista
- **WHEN** la denuncia trae un motivo que no está en la lista
- **THEN** la API responde 400 `validacion`

### Requirement: Cadena de filtros
Todo contenido nuevo y toda denuncia SHALL pasar por la cadena texto → imagen → reputación del
autor → revisión humana. Lo dudoso MUST entrar a la cola de casos y lo claramente válido puede
publicarse sin revisión humana.

#### Scenario: Reseña con insultos
- **WHEN** una reseña nueva contiene palabras de la lista de bloqueo
- **THEN** queda en revisión con un caso en la cola y no se publica sola

#### Scenario: Reseña limpia de un vecino confiable
- **WHEN** una reseña sin alertas la escribe un vecino de nivel 2 sin sanciones
- **THEN** se publica sin esperar a un moderador

### Requirement: Cola de casos para moderadores
`GET /v1/moderacion/casos` SHALL listar los casos por estado con paginación por cursor solo para el
rol `moderador`, sin exponer el teléfono de nadie.

#### Scenario: Vecino sin rol
- **WHEN** un vecino sin rol de moderador pide la cola de casos
- **THEN** la API responde 403 `rol_requerido`

### Requirement: Decidir un caso
`POST /v1/moderacion/casos/{id}/decision` SHALL aceptar `publicar`, `ocultar`, `restaurar`,
`descartar` o `sancionar`, siempre con motivo, y MUST registrar quién decidió y cuándo.

#### Scenario: Ocultar una reseña denunciada
- **WHEN** un moderador decide `ocultar` con un motivo
- **THEN** se registra `moderacion.contenido_ocultado` y la reseña deja de ser pública

#### Scenario: Sancionar al autor
- **WHEN** un moderador decide `sancionar`
- **THEN** el contenido se oculta y su autor no puede publicar durante el plazo de la sanción

### Requirement: Lo ocultado sale de todas partes
Cuando se oculta un contenido, su módulo dueño SHALL marcarlo como oculto, de modo que MUST
desaparecer de las búsquedas, de las respuestas de la API y de los Sync Streams; al restaurarlo,
vuelve.

#### Scenario: Publicación del muro ocultada
- **WHEN** un moderador oculta una publicación del muro
- **THEN** deja de aparecer en `GET /v1/publicaciones` y en los Sync Streams del muro

### Requirement: Reseñas en revisión
Las reseñas en revisión SHALL publicarse u ocultarse desde la cola, y al publicarse MUST recalcularse
el ranking de su servicio.

#### Scenario: Moderador publica una reseña
- **WHEN** un moderador decide `publicar` una reseña en revisión
- **THEN** la reseña pasa a publicada y el servicio recalcula su puntaje

### Requirement: Tiempo hasta la primera revisión
El sistema SHALL medir el tiempo entre la creación de cada caso y su primera revisión humana, y MUST
exponerlo a los administradores para el criterio de salida.

#### Scenario: Métrica del piloto
- **WHEN** un administrador consulta las métricas de moderación de la semana
- **THEN** recibe el número de casos, cuántos siguen pendientes y el p90 del tiempo hasta la primera revisión
