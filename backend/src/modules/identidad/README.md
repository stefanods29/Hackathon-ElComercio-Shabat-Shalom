# Módulo `identidad`

**Responsabilidad:** zonas del vecindario, usuarios con su nivel de confianza y roles, y emisión
de tokens (acceso a la API y sincronización con PowerSync).

**Hoy:** OTP por SMS/WhatsApp, elección inicial de zona, refresh tokens rotativos, cierre de
sesión y revocación total. `GET /v1/sync/credenciales` comprueba que la familia siga activa y
relee zona, nivel y roles. La sesión de desarrollo (`POST /v1/dev/sesiones`) se conserva sin
refresh ni familia y está prohibida en producción.

`identidad.sesiones` guarda únicamente HMAC de los refresh tokens y nunca se replica por
PowerSync. Rotación y revocación se serializan por usuario. Reutilizar un refresh ya rotado
revoca su familia; el 401 se lanza después de confirmar la revocación. El consumo OTP y la
creación de sesión también son atómicos.

Configuración nueva: `REFRESH_TOKEN_SECRET` (mínimo 32 caracteres, generado por `dev:keys`) y
`REFRESH_TOKEN_DAYS` (1–365; por defecto 30). El acceso dura como máximo 15 minutos; tras
revocar, los tokens ya emitidos valen hasta vencer, pero no se emiten refresh ni credenciales
de sync nuevos. La elección de zona conserva `sid` y exige familia activa al emitir acceso.

Las rutas de autenticación son en línea, sin cola offline ni `Idempotency-Key`. El cliente debe
serializar las renovaciones y guardar el refresh nuevo antes de usarlo. Una respuesta perdida
requiere iniciar sesión por OTP: reusar el refresh anterior cierra la familia.

Evidencia y puntos de contacto: `docs/fase-0/evidencias/sesiones.md`.

Esquema propio: `identidad.*`. Migraciones en `infrastructure/migrations/`.
