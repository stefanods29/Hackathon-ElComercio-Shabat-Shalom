# 0003 · Tokens ES256 con JWKS

**Contexto.** PowerSync valida los JWT del celular con una clave pública (`jwks_uri`).

**Decisión.** La API firma JWT ES256 (P-256) y publica la clave pública en
`/.well-known/jwks.json`. Hay dos audiencias: `vecinal-api` (acceso, 15 min) y `powersync`
(sincronización, 10 min); un token de una no sirve para la otra. Los claims `sub`, `zona`, `nivel`
y `roles` alimentan los Sync Streams. En la Fase 0 la sesión de desarrollo
(`POST /v1/dev/sesiones`, apagada por defecto y prohibida en producción) reemplaza al OTP hasta
que el Lote B lo entregue.

**Consecuencias.** Rotar la clave es publicar un nuevo `kid`; las credenciales de sync se vuelven
a emitir leyendo zona y nivel desde la base.
