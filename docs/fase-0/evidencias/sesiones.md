# Sesiones revocables · Lote B, Parte 2

Fecha: 2026-11-07. Rama: `lote-b/parte-2-sesiones`. Base:
`9b5054073dea147dcf081a3ad529f6fbec1b16b6` (Parte 1 con bloqueos OTP corregidos).
Contrato previo: `2983484`. Entrega conservada en su rama, pendiente de revisión;
sin merge, rebase, cherry-pick ni PR por indicación del equipo.

## Resultado

- OTP correcto crea una familia y devuelve acceso con `sid`, `refreshToken` y
  `refreshExpiraEn`. Consumir OTP, crear usuario/sesión y firmar son atómicos.
- `POST /v1/auth/refrescar` consume el refresh, conserva familia/dispositivo y devuelve
  un par nuevo con zona, nivel y roles releídos de la base.
- Reutilizar un refresh ya rotado revoca toda su familia y responde 401
  `sesion_revocada` después del commit. No afecta otros dispositivos.
- Cerrar sesión revoca la familia actual; revocar todas incluye todos los dispositivos.
  Ambos requieren acceso válido y son idempotentes sin `Idempotency-Key`.
- Sync comprueba usuario y familia activa, excluyendo filas rotadas, revocadas y vencidas.
  Elegir zona conserva `sid`, exige familia activa y firma dentro de su transacción.
- Creación, rotación y revocación toman el mismo bloqueo transaccional por usuario.
  Así una revocación total no omite el refresh insertado por una rotación concurrente.

## Migración y configuración

Ejecutar `npm run db:migrate` con el entorno configurado. La nueva migración
`202611070200_identidad_sesiones` crea `identidad.sesiones`, sus índices y el hash único.
La tabla es privada y no pertenece a la publicación ni a los streams de PowerSync.

Variables documentadas en `backend/.env.example`:

| Variable | Regla |
|---|---|
| `REFRESH_TOKEN_SECRET` | Obligatoria, mínimo 32 caracteres; independiente del secreto OTP |
| `REFRESH_TOKEN_DAYS` | Entre 1 y 365; por defecto 30, renovados desde cada rotación |
| `JWT_ACCESS_MINUTES` | Entre 1 y 15; por defecto 15 |

`npm run dev:keys` genera un secreto refresh nuevo junto con las claves existentes.
Si ya existe `.env`, el script lo conserva; se debe añadir la nueva variable localmente.
Cambiar el secreto refresh invalida los refresh existentes. Nunca se guarda ni registra el
refresh en claro: se almacenan HMAC-SHA256 de tokens opacos de 32 bytes aleatorios.

## Verificación local

Entorno: Node 26.13.0, PostgreSQL 18.6 y PostGIS 3.7. Las pruebas crean, migran y eliminan
una base temporal; no usan datos reales ni envían SMS.

| Comprobación | Resultado |
|---|---|
| `npm run verify` | 66 pruebas unitarias; tipos, lint sin advertencias, formato, fronteras, Sync Streams y build correctos |
| `npm run test:integration` | 59 pruebas en 7 archivos con PostgreSQL real |
| `npm run graph` | Ejecutado; grafo de módulos vigente |
| `redocly lint` (2.76.0) | Sin errores; 3 advertencias preexistentes sobre respuestas 4xx (salud, JWKS, zonas) |
| `openspec validate --all --strict` | 10 aprobados, 0 fallidos |
| `git diff --check` | Correcto |

Las 8 unitarias de `RefreshSession` usan reloj fijo y repositorio en memoria con rollback.
Las 19 pruebas HTTP nuevas cubren hashes y restricciones, rotación, token robado, concurrencia,
familias independientes, vencimiento, cuenta eliminada, cierre, revocación total, propiedad de
familia, zona, autenticación, validación, compatibilidad de desarrollo y fallos de firma.
La migración también se revierte y aplica dentro de una transacción que se deshace al terminar.
Se conservan las regresiones de límites y bloqueos OTP de la Parte 1.

CI remoto pendiente de ejecución manual sobre esta rama; no se declara verde todavía.
Las tareas 2.1–2.3 están verificadas; 2.4 permanece abierta hasta confirmar CI.

## Puntos de contacto y límites

Para el Lote A: serializar las renovaciones, persistir el par nuevo en almacenamiento seguro
antes de usarlo y excluir autenticación de la cola offline y de reintentos automáticos.
No existe ventana de gracia: perder la respuesta de renovación requiere iniciar sesión por
OTP; reenviar el refresh anterior revoca la familia. Elegir zona no rota ni devuelve refresh.

Revocar corta la emisión de tokens nuevos y credenciales de sincronización. Los accesos
ya emitidos siguen valiendo hasta vencer (máximo 15 minutos), y las credenciales PowerSync
ya emitidas hasta su propio vencimiento. No se promete desconexión inmediata de PowerSync.
La sesión de desarrollo no tiene `sid` ni refresh y su cierre es un no-op; sigue prohibida
en producción. Los accesos OTP previos sin `sid` conservan su vigencia hasta expirar y no se
pueden vincular retroactivamente a una familia; requieren OTP para obtener una sesión revocable.

Para la Parte 3: `IssueCredentials.forSync` ahora recibe un `Actor`, no un id; sus pruebas
deben pasar el actor completo al integrar. Esta rama no incorpora roles/guards de esa parte.
La prueba manual real de Twilio de la Parte 1 (tarea 1.4) continúa pendiente y no forma parte
de esta verificación.
