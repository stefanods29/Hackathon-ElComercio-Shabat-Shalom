# plataforma/convenciones-api Specification

## Purpose
Reglas comunes de la API REST que comparten la app móvil y la consola web: versión, autenticación, formato de errores y sonda de salud.

## Requirements

### Requirement: Errores en formato Problem Details
Toda respuesta de error SHALL usar `application/problem+json` (RFC 9457) con `type`, `title`, `status` y un `codigo` estable que el celular usa para decidir qué mostrar. Los errores inesperados MUST NOT revelar detalles internos.

#### Scenario: Rechazo por regla de negocio
- **WHEN** un vecino intenta tomar un favor que otro vecino ya tomó
- **THEN** la API responde 409 con `codigo` = `favor_no_disponible` y un `detail` en lenguaje simple

#### Scenario: Error inesperado
- **WHEN** ocurre una falla interna no prevista
- **THEN** la API responde 500 con `codigo` = `error_interno` y sin trazas, consultas ni secretos

### Requirement: Validación de entrada
La API SHALL validar cuerpos y parámetros antes de ejecutar un caso de uso y MUST responder 400 con la lista de campos inválidos (`errores[].campo` y `errores[].mensaje`).

#### Scenario: Publicación con datos inválidos
- **WHEN** el cuerpo trae un `id` que no es UUIDv7 y un título de dos letras
- **THEN** la API responde 400 con `codigo` = `validacion` y un error por cada campo

### Requirement: Autenticación por defecto
Toda ruta SHALL exigir un token de acceso Bearer válido, salvo las marcadas como públicas (salud, JWKS y sesión de desarrollo).

#### Scenario: Llamada sin token
- **WHEN** se llama a `POST /v1/publicaciones` sin cabecera `Authorization`
- **THEN** la API responde 401 con `codigo` = `no_autenticado`

### Requirement: Sonda de salud
`GET /v1/salud` SHALL responder 200 cuando la base de datos responde y 503 cuando no, sin exigir token.

#### Scenario: Base de datos caída
- **WHEN** la API no puede consultar PostgreSQL
- **THEN** `GET /v1/salud` responde 503 con `baseDeDatos` = `caida`
