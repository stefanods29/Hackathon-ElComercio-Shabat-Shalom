# Módulo `identidad`

**Responsabilidad:** zonas del vecindario, usuarios con su nivel de confianza y roles, y emisión
de tokens (acceso a la API y sincronización con PowerSync).

**Hoy:** sesión de desarrollo (`POST /v1/dev/sesiones`) y credenciales de sync
(`GET /v1/sync/credenciales`). **Lote B** agrega OTP, sesiones revocables y roles.

Esquema propio: `identidad.*`. Migraciones en `infrastructure/migrations/`.
