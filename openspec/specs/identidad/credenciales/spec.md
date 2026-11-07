# identidad/credenciales Specification

## Purpose
Emisión de tokens para la API y para PowerSync, y publicación de las claves públicas que permiten validarlos.

## Requirements

### Requirement: Sesión de desarrollo
`POST /v1/dev/sesiones` SHALL iniciar sesión con el teléfono de un vecino existente solo cuando `ENABLE_DEV_SESSION` está activo. En producción MUST responder 404 y la API MUST NOT arrancar si se intenta habilitar.

#### Scenario: Entorno de desarrollo
- **WHEN** un desarrollador envía el teléfono de un vecino sembrado
- **THEN** recibe un token de acceso ES256 de 15 minutos con los claims `sub`, `zona`, `nivel` y `roles`

#### Scenario: Sesión de desarrollo apagada
- **WHEN** `ENABLE_DEV_SESSION` es falso
- **THEN** la ruta responde 404

### Requirement: Credenciales de sincronización
`GET /v1/sync/credenciales` SHALL entregar la URL de PowerSync y un token de audiencia `powersync` con `sub` y `zona`, releyendo zona y nivel desde la base en cada emisión.

#### Scenario: Vecino que cambió de zona
- **WHEN** el celular pide credenciales después de que el vecino cambió de zona
- **THEN** el nuevo token trae la zona nueva y los Sync Streams envían los datos de esa zona

### Requirement: Audiencias separadas
Un token de PowerSync MUST NOT ser aceptado por la API REST, y un token de acceso MUST NOT ser aceptado como token de sincronización.

#### Scenario: Token de PowerSync usado en la API
- **WHEN** se llama a la API con un token de audiencia `powersync`
- **THEN** la API responde 401

### Requirement: Claves públicas
`GET /.well-known/jwks.json` SHALL publicar solo la parte pública de la clave ES256 vigente, con su `kid`.

#### Scenario: PowerSync valida un token
- **WHEN** PowerSync recibe un token del celular
- **THEN** lo valida con la clave publicada en el JWKS, que no contiene el componente privado
