# Spec Delta

## Purpose

Sesiones de larga duración en el celular que se pueden renovar, cerrar y revocar desde otro dispositivo si se pierde el teléfono.

## ADDED Requirements

### Requirement: Renovación rotativa
`POST /v1/auth/refrescar` SHALL cambiar un refresh token válido por un token de acceso nuevo y un refresh token nuevo, invalidando el anterior. Solo se guarda el hash del refresh token.

#### Scenario: Token de acceso vencido
- **WHEN** el celular presenta su refresh token vigente
- **THEN** recibe un par nuevo y el refresh token anterior deja de servir

### Requirement: Detección de reutilización
Si se presenta un refresh token ya rotado, la API SHALL revocar toda la familia de sesiones de ese dispositivo y MUST responder 401.

#### Scenario: Token robado y reutilizado
- **WHEN** un atacante presenta un refresh token que el celular ya rotó
- **THEN** la API revoca esa sesión y el celular legítimo debe volver a iniciar sesión

### Requirement: Cerrar sesión y revocar todo
`POST /v1/auth/cerrar-sesion` SHALL revocar la sesión actual y `POST /v1/auth/sesiones/revocar` MUST revocar todas las sesiones del vecino.

#### Scenario: Teléfono perdido
- **WHEN** el vecino revoca todas sus sesiones desde otro dispositivo
- **THEN** el teléfono perdido ya no obtiene tokens nuevos ni credenciales de sincronización
