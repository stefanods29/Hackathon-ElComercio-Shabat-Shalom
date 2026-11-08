# Spec Delta

## Purpose

Que el directorio de emergencia se mantenga desde la consola, con su fuente y su fecha, y que cada
versión publicada quede registrada (secciones 3.4, 7.3 y 9.1 de la arquitectura). Reemplaza la
edición por PR de la Fase 1.

## ADDED Requirements

### Requirement: Publicación validada contra el esquema de la Fase 1
`PUT /v1/operacion/directorio-emergencia/{archivo}` SHALL aceptar solo un directorio que cumpla
`contracts/directorio-emergencia.schema.json`. Cada entrada lleva su fuente y su fecha de
verificación, y una fecha de verificación MUST NOT estar en el futuro. Los errores SHALL volver
como 422 `directorio_invalido`, con el campo y el motivo de cada uno.

#### Scenario: Número sin teléfono
- **WHEN** un curador publica una entrada de tipo `numero` sin `telefono`
- **THEN** la API responde 422 con el campo de esa entrada y no publica nada

### Requirement: Versiones con control de concurrencia
Cada publicación SHALL subir la versión en 1 a partir de `versionVista` y guardar la versión, su
contenido, su SHA-256, quién la publicó y cuándo. Si `versionVista` no es la versión actual, la API
MUST responder 409 `conflicto_de_version`.

#### Scenario: Dos curadores a la vez
- **WHEN** dos curadores publican sobre la versión 3
- **THEN** el primero publica la versión 4 y el segundo recibe 409 `conflicto_de_version`

### Requirement: Archivo e índice en la CDN
Al publicar, SHALL escribirse `emergencia/<archivo>` y `emergencia/indice.json` con el mismo
formato del script de la Fase 1: versión, SHA-256, tamaño y zonas. Solo MUST aceptarse archivos que
ya figuran en el índice.

#### Scenario: Archivo desconocido
- **WHEN** se intenta publicar `otro-distrito.json` y no figura en el índice
- **THEN** la API responde 404 y no escribe nada

### Requirement: Solo roles autorizados
La curaduría SHALL estar disponible para `administrador` y `coordinador`, y para `curador` cuando el
Lote B lo agregue. Cualquier otro rol recibe 403 `rol_requerido`.

#### Scenario: Moderador sin rol de curaduría
- **WHEN** un moderador intenta publicar el directorio
- **THEN** la API responde 403 `rol_requerido`
