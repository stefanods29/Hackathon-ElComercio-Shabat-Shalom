# Lote B · API, identidad y trabajos

| Dato | Valor |
|---|---|
| Dificultad | ★★★ Alta (el segundo más complejo de la Fase 0) |
| Área | Solo `backend/` y `contracts/openapi.yaml` (más docs del lote) |
| Change de OpenSpec | `openspec/changes/lote-b-api-identidad-y-trabajos/` (proposal, design, specs, tasks) |
| Issue de GitHub | #2 · Lote B · API, identidad y trabajos |
| Partes | 6, en orden. Una rama y una entrega por parte |
| Repositorio | https://github.com/stefanods29/Hackathon-ElComercio-Shabat-Shalom (rama `main`) |

> Las tareas con casillas viven en `openspec/changes/lote-b-api-identidad-y-trabajos/tasks.md`; esta guía explica cómo hacerlas.

## Estado del lote

| Parte | Qué entrega | Estado | Responsable | PR |
|---|---|---|---|---|
| 1 | Inicio de sesión con OTP y elección de zona | Pendiente | Por asignar | — |
| 2 | Sesiones revocables | Pendiente | Por asignar | — |
| 3 | Roles y niveles de confianza | En curso | JDiazD33 (con Kimi como asistente) | — |
| 4 | Eventos y trabajos (pg-boss, outbox y workers) | Hecha | JDiazD33 | [#5](https://github.com/stefanods29/Hackathon-ElComercio-Shabat-Shalom/pull/5) |
| 5 | Muro completo | Pendiente | Por asignar | — |
| 6 | Capacidad (k6) | Pendiente | Por asignar | — |

Estados posibles: **Pendiente**, **En curso** o **Hecha** (integrada en `main`). Quien toma una
parte la marca **En curso** con su nombre (en el issue del lote o en un PR pequeño) para que
nadie la duplique, y la marca **Hecha** en el PR que la entrega. Lo que ya está hecho está en
la sección 0.2; lo que falta son las partes pendientes de esta tabla.

---

## 0. Antes de empezar (léelo completo)

### 0.1 Reglas obligatorias

1. **Archivos personales fuera del repo.** La configuración local de tu editor u otras herramientas va en
   `.git/info/exclude`, nunca en el repo ni en el `.gitignore`.
2. **Commits con tu identidad de GitHub** (`git config user.name` y `git config user.email`).
3. **Una parte, una rama, un PR.** Al terminar la parte, sube tu rama y abre el PR con la plantilla.
   El Lote A lo revisa e integra (`docs/fase-0/revision-y-entregas.md`).
4. **Código en inglés; contenido en español.** En inglés: clases, funciones, variables, archivos,
   variables de entorno y scripts. En español: rutas (`/v1/auth/otp`), campos JSON (`telefono`,
   `codigo`), códigos de error (`codigo_invalido`), tablas y columnas, carpetas de módulos
   (`identidad`, `solidaridad`, `notificaciones`), mensajes para el vecino y documentación.
5. **Primero el contrato.** Toda ruta nueva entra antes en `contracts/openapi.yaml`, en un commit
   propio al inicio de la parte, validado con `npx @redocly/cli lint contracts/openapi.yaml`.
6. **Compilar y depurar al final de cada parte**, sin excepción (sección 0.4).
7. **Fronteras del monolito:** un módulo solo usa a otro por su `index.ts` o por eventos.
   `npm run boundaries` debe quedar en verde.
8. **Seguridad:** ningún secreto en el repo. Cada variable nueva va a `backend/.env.example` con
   un valor de ejemplo inofensivo y al esquema de `src/shared/config/app-config.ts`. Nunca
   registres en logs códigos OTP, refresh tokens ni tokens de acceso (salvo el adaptador falso de
   OTP, y solo en `NODE_ENV=development`).
9. **No toques áreas de otros lotes** salvo los puntos de contacto de la sección 8.

### 0.2 Lo que ya está hecho (cimientos en `main`)

Patrón de referencia: `backend/src/modules/solidaridad/`. Cópialo para todo lo nuevo:

```text
src/modules/<modulo>/
├── domain/          # TypeScript puro: entidades, reglas, eventos (sin NestJS, Kysely ni HTTP)
├── application/     # casos de uso (@Injectable) y puertos (interfaces + Symbol)
├── infrastructure/  # adaptadores Kysely, migrations/, clientes externos, dobles *.memory.ts
├── api/             # controladores y esquemas Zod (alineados con el contrato)
├── <name>.module.ts
└── index.ts         # interfaz pública: lo único que otros módulos pueden importar
```

Piezas compartidas que vas a usar (`src/shared/`):

| Pieza | Archivo | Uso |
|---|---|---|
| Errores de dominio | `domain/errors.ts` | `BusinessRuleViolation(code, message, kind, extensions)` con `kind` = `'conflict'` (409), `'forbidden'` (403) o `'invalid'` (422); `ResourceNotFound`; `VersionConflict`; `ValidationError` |
| Problem Details | `api/problem-details.ts`, `api/problem-details.filter.ts` | `toProblemDetails()` traduce los errores; `isDefinitiveRejection()` (4xx salvo 408 y 429) |
| Validación | `api/validation.ts` | `@Body({ schema })`, `@Param('id', { schema })` con Zod 4 |
| Autenticación | `auth/actor.ts`, `auth/decorators.ts`, `auth/auth.guard.ts`, `auth/token.service.ts` | `@Public()`, `@CurrentActor()`, `Actor { id, zoneId, trustLevel, roles }`, `TokenService.issueAccess/issueSync/verifyAccess`; claims `sub`, `zona`, `nivel`, `roles` |
| Idempotencia | `idempotency/*` | `@Idempotent()` en toda escritura que el celular reintenta; `PostgresIdempotencyStore.deleteExpired(now)` |
| Unidad de trabajo | `db/unit-of-work.ts`, `db/unit-of-work.kysely.ts` | `UNIT_OF_WORK.run(async (tx) => …)`, `asKysely<Tables>(tx)`, `asJsonb(value)` |
| Conexión | `db/connection.ts` | `KYSELY` para lecturas fuera de transacción |
| Outbox | `outbox/*` | `OUTBOX_WRITER.record(tx, 'modulo', aggregate.pullEvents())`; tabla `compartido.outbox` con `publicado_en` e `intentos` |
| Colas | `queues/job-queue.ts`, `queues/job-queue.memory.ts` | Puerto `JobQueue { enqueue(name, data, options), process(name, handler) }`; `JobOptions { priority, retries, singletonKey, delaySeconds }`; doble `InMemoryJobQueue` con `drain()` |
| Configuración | `config/app-config.ts` | Esquema Zod de variables; `APP_CONFIG` |
| Reloj | `domain/clock.ts` | `CLOCK`, `Clock { now() }`: úsalo siempre en lugar de `new Date()` |

Módulo `identidad` hoy: `POST /v1/dev/sesiones` (solo desarrollo), `GET /v1/sync/credenciales`,
`IssueCredentials { startDevSession(phone), forSync(userId) }`,
`UserRepository { findByPhone, findById }` y tabla `identidad.usuarios`. Restricciones:
`telefono` en formato `^\+[1-9][0-9]{7,14}$`, `nombre_visible` de 2 a 60 caracteres,
`nivel_confianza` de 0 a 3, `roles` dentro de `proveedor | moderador | coordinador | brigadista | administrador`.

Pruebas:

- Unitarias: `*.spec.ts` junto al código (Vitest con `globals`).
- Integración: `test/integration/*.int-spec.ts`. La configuración global crea una base temporal,
  aplica todas las migraciones y siembra los vecinos de `scripts/seed-data.ts`: `ana` (nivel 2),
  `beto` (1), `carla` (3, coordinadora), `dario` (0) y `elena` (2, otra zona). Levanta la API con
  `createTestApp(inject('databaseUrl'), { VARIABLE: 'valor' })` de `test/support/app.ts`.
- Los archivos de integración comparten la misma base y corren en serie. Usa **teléfonos e ids
  únicos por prueba** para que no se pisen.

Migraciones: `src/modules/<modulo>/infrastructure/migrations/YYYYMMDDHHmm_<modulo>_<descripcion>.ts`
con `up` y `down` usando `sql.raw`, igual que
`identidad/infrastructure/migrations/202611060110_identidad_zonas_y_usuarios.ts`. En las cadenas
de TypeScript las barras invertidas del SQL van dobles (`'^\\+[1-9]…'`). Una tabla solo se agrega a
la publicación `powersync` si sus datos deben llegar a los celulares; ninguna tabla de este lote
lo necesita.

### 0.3 Preparar el entorno

```bash
git clone https://github.com/stefanods29/Hackathon-ElComercio-Shabat-Shalom.git
cd Hackathon-ElComercio-Shabat-Shalom
git config user.name "<tu nombre>"
git config user.email "<tu correo de GitHub>"
cd infra && docker compose up -d && cd ../backend
npm ci
npm run dev:keys && npm run db:migrate && npm run db:seed
npm run start:dev                      # http://localhost:3000/v1/salud
```

Requisitos: Node 26, Docker Desktop y Git. OpenSpec: `npm i -g @fission-ai/openspec@1.16.1`.

### 0.4 Ciclo de cada parte

1. `git switch main && git pull` y luego `git switch -c lote-b/parte-<n>-<tema>`.
2. Lee la parte en `tasks.md`, los escenarios de `specs/` y esta guía.
3. Commit 1: el contrato (`contracts/openapi.yaml`), validado con Redocly.
4. Implementa con pruebas: dominio → casos de uso → adaptadores → API.
5. **Compila y depura** desde `backend/`:
   ```bash
   npm run verify
   DATABASE_URL_ADMIN=postgres://postgres:postgres@localhost:5432/postgres npm run test:integration
   npm run graph            # si cambiaron dependencias entre módulos
   cd .. && npx @redocly/cli lint contracts/openapi.yaml && openspec validate --all --strict
   ```
   Con la base de Docker, el usuario administrador es `vecinal:vecinal`
   (`DATABASE_URL_ADMIN=postgres://vecinal:vecinal@localhost:5432/vecinal`).
6. Marca las tareas `[x]` en `tasks.md`. Si cambió un comportamiento, actualiza el `spec.md` del
   change.
7. Sube la rama y abre el PR con el **informe de entrega** (sección 9) como descripción.

---

## Parte 1 · Inicio de sesión con OTP

Rama: `lote-b/parte-1-otp` · Tareas 1.1–1.6 · Spec: `specs/identidad/inicio-de-sesion/spec.md`

### 1.1 Contrato

Agrega bajo la etiqueta `identidad`:

- `POST /v1/auth/otp` (`operationId: solicitarCodigo`, público).
  Cuerpo `SolicitudOtp { telefono: string (E.164), canal?: 'sms' | 'whatsapp' (por defecto 'sms') }`.
  Responde **202** `OtpEnviado { reintentarEnSegundos: integer, expiraEnSegundos: integer }`, el
  **mismo cuerpo exista o no la cuenta**. Errores: 400 `validacion` y 429 `demasiados_intentos`
  con la cabecera `Retry-After`.
- `POST /v1/auth/otp/verificar` (`operationId: verificarCodigo`, público).
  Cuerpo `VerificacionOtp { telefono, codigo: string (patrón ^[0-9]{6}$), dispositivo?: string (≤ 80) }`.
  Responde **200** con el esquema `Sesion` que ya existe (`tokenDeAcceso`, `expiraEn`,
  `usuario`); en la Parte 2 se le agregan los campos del refresh. Errores: 401 `codigo_invalido`,
  el mismo para un código incorrecto, vencido o ya usado, para no dar pistas; y 429
  `demasiados_intentos`.
- Agrega la respuesta reutilizable `DemasiadasSolicitudes` (429, Problem Details con la extensión
  `reintentarEnSegundos` y la cabecera `Retry-After`).
- `GET /v1/zonas` (`operationId: listarZonas`, público): 200 con una lista de
  `Zona { id, nombre, distrito }`, **sin el polígono**.
- `PUT /v1/yo/zona` (`operationId: elegirZona`, con token y `@Idempotent()`): cuerpo `{ zonaId }`
  → 200 `Sesion`, con un token de acceso que ya incluye la zona. 404 si la zona no existe y 409
  `zona_ya_elegida` si el vecino ya tenía una (cambiar de zona llega en la Fase 1). Lo usa la
  pantalla "Elige tu zona" del Lote D.

Las dos rutas de OTP **no** llevan `@Idempotent()`: el inicio de sesión es en línea y no pasa por
la cola offline.

### 1.2 Soporte de 429 en el núcleo compartido (cambio pequeño y cuidadoso)

- `src/shared/domain/errors.ts`: agrega
  `export class RateLimitExceeded extends ApplicationError` con `code` configurable y
  `retryAfterSeconds`, con la extensión `{ reintentarEnSegundos }`.
- `src/shared/api/problem-details.ts`: `toProblemDetails` lo traduce a **429**.
- `src/shared/api/problem-details.filter.ts`: si el problema trae `reintentarEnSegundos` numérico,
  agrega la cabecera `Retry-After`. Así funciona también al repetir una respuesta guardada
  (`PrebuiltProblem`).
- Agrega también `AuthenticationFailure(code, message)` → **401** con ese `code`. La usan las
  Partes 1 y 2 (`codigo_invalido`, `sesion_invalida`, `sesion_revocada`).
- Pruebas en `problem-details.spec.ts` para 429 y para 401 con código propio. Recuerda que
  `isDefinitiveRejection(429)` es `false`, así que la idempotencia libera la clave (correcto).

### 1.3 Migración `identidad.codigos_otp`

Archivo `src/modules/identidad/infrastructure/migrations/202611070100_identidad_codigos_otp.ts`:

```sql
CREATE TABLE identidad.codigos_otp (
  id           uuid        PRIMARY KEY DEFAULT uuidv7(),
  telefono     text        NOT NULL CHECK (telefono ~ '^\+[1-9][0-9]{7,14}$'),
  codigo_hash  text        NOT NULL,
  canal        text        NOT NULL CHECK (canal IN ('sms', 'whatsapp')),
  ip           inet,
  intentos     smallint    NOT NULL DEFAULT 0,
  expira_en    timestamptz NOT NULL,
  usado_en     timestamptz,
  creado_en    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX codigos_otp_telefono_idx ON identidad.codigos_otp (telefono, creado_en DESC);
CREATE INDEX codigos_otp_ip_idx ON identidad.codigos_otp (ip, creado_en DESC);
```

`down`: `DROP TABLE identidad.codigos_otp;`. No va a la publicación `powersync` ni se le da
`GRANT` a `powersync_rol`. Agrega `OtpCodesTable` a `IdentityTables` en
`infrastructure/tables.ts`.

### 1.4 Configuración

En `app-config.ts` y `.env.example`:

| Variable | Tipo y valor por defecto | Regla |
|---|---|---|
| `OTP_PROVIDER` | `'fake' \| 'twilio'`, por defecto `'fake'` | `superRefine`: prohibido `fake` en `production` |
| `OTP_HASH_SECRET` | texto de 32 caracteres o más | obligatorio |
| `OTP_TTL_MINUTES` | entero, 5 | |
| `OTP_MAX_REQUESTS_PER_PHONE` | entero, 3 (por cada 15 min) | |
| `OTP_MAX_REQUESTS_PER_IP` | entero, 20 (por hora) | |
| `OTP_MAX_ATTEMPTS` | entero, 5 | |
| `OTP_LOCK_MINUTES` | entero, 15 | |
| `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_FROM_SMS`, `TWILIO_FROM_WHATSAPP` | opcionales | obligatorios si `OTP_PROVIDER=twilio` |

Actualiza `scripts/generate-keys.ts` para que también escriba un `OTP_HASH_SECRET` aleatorio
(`randomBytes(32).toString('base64url')`) y `test/support/config.ts` para que las pruebas usen
`OTP_PROVIDER: 'fake'` y un secreto fijo de prueba.

### 1.5 Puertos y adaptadores

En `application/ports.ts`:

```ts
export type OtpChannel = 'sms' | 'whatsapp';
export interface OtpProvider {
  send(phone: string, code: string, channel: OtpChannel): Promise<void>;
}
export const OTP_PROVIDER = Symbol('OTP_PROVIDER');

export interface OtpCodeRecord { id; phone; codeHash; channel; ip; attempts; expiresAt; usedAt; createdAt }
export interface OtpCodeRepository {
  create(transaction, record): Promise<void>;
  findLatestActiveForUpdate(transaction, phone, now): Promise<OtpCodeRecord | null>; // FOR UPDATE
  countByPhoneSince(phone, since): Promise<{ count: number; oldest: Date | null }>;
  countByIpSince(ip, since): Promise<{ count: number; oldest: Date | null }>;
  incrementAttempts(transaction, id): Promise<number>;
  markUsed(transaction, id, now): Promise<boolean>; // UPDATE … WHERE usado_en IS NULL
}
export const OTP_CODE_REPOSITORY = Symbol('OTP_CODE_REPOSITORY');
```

Agrega a `UserRepository` el método `findOrCreateByPhone(transaction, phone)`: inserta con
`nivel_confianza = 0`, `nombre_visible = 'Vecino nuevo'` y
`ON CONFLICT (telefono) DO NOTHING`, y si no insertó, lee la fila existente.

Adaptadores en `infrastructure/`:

- `otp-code.repository.kysely.ts` (`KyselyOtpCodeRepository`) y `otp-code.repository.memory.ts`
  (doble para las pruebas unitarias; solo lo importan los `*.spec.ts`).
- `fake-otp.provider.ts` (`FakeOtpProvider`): guarda `sent: { phone, code, channel }[]` y ofrece
  `lastCodeFor(phone)`. Solo en `development` escribe el código en el log.
- `twilio-otp.provider.ts` (`TwilioOtpProvider`): `fetch` a
  `https://api.twilio.com/2010-04-01/Accounts/{sid}/Messages.json` con autenticación básica y
  cuerpo `application/x-www-form-urlencoded` (`To`, `From`, `Body`). Para WhatsApp antepone
  `whatsapp:` a `To` y `From`. Texto: "Tu código de Vecinal es 123456. Vence en 5 minutos. No lo
  compartas." No registra el código. Si Twilio falla, lanza un error que termine en 503.
  Si el equipo elige Twilio Verify o Firebase Auth (decisión abierta 4 de la sección 13.3),
  adapta el puerto y registra la decisión en `docs/adr/0008-proveedor-otp.md`.
- En `identity.module.ts`, el proveedor `OTP_PROVIDER` se elige con `useFactory` según
  `OTP_PROVIDER`.

### 1.6 Casos de uso

`application/request-otp.ts` → `RequestOtp.execute({ phone, channel, ip })`:

1. Límite por teléfono: si hay `OTP_MAX_REQUESTS_PER_PHONE` o más solicitudes en los últimos
   15 minutos, lanza `RateLimitExceeded('demasiados_intentos', …, segundos hasta que salga la
   más antigua de la ventana)`. Haz lo mismo por IP en la última hora.
2. Código: `randomInt(0, 1_000_000).toString().padStart(6, '0')` de `node:crypto`.
3. Hash: `createHmac('sha256', OTP_HASH_SECRET).update(`${phone}:${code}`).digest('hex')`.
4. Guarda el registro (vence en `OTP_TTL_MINUTES`) y envía con el proveedor.
5. Devuelve `{ retryAfterSeconds: 60, expiresInSeconds }`: la misma respuesta exista o no la cuenta.

`application/verify-otp.ts` → `VerifyOtp.execute({ phone, code, device })`:

1. Dentro de `unitOfWork.run`: `findLatestActiveForUpdate`. Si no hay código vigente, el
   resultado es `invalid`.
2. Si `attempts >= OTP_MAX_ATTEMPTS`, el resultado es `locked` (con los segundos de bloqueo).
3. Compara los hashes con `timingSafeEqual` (los dos `Buffer` del mismo largo). Si no coinciden:
   `incrementAttempts` y el resultado es `mismatch`.
4. Si coinciden: `markUsed` (si devuelve `false`, otro pedido lo usó primero y el resultado es
   `invalid`), `findOrCreateByPhone` y el resultado es `ok` con el usuario.
5. **Fuera de la transacción**, según el resultado: lanza `AuthenticationFailure('codigo_invalido')`,
   `RateLimitExceeded('demasiados_intentos')` o emite el token de acceso.

> **Trampa:** si lanzas el error dentro de `unitOfWork.run`, la transacción se deshace y el
> incremento de intentos se pierde: la fuerza bruta quedaría sin límite. Devuelve un resultado y
> lanza después del commit.

Controlador `api/auth.controller.ts`: `@Controller(\`${V1}/auth\`)` con `@Public()`.
`@Post('otp') @HttpCode(202)` y `@Post('otp/verificar') @HttpCode(200)`. La IP sale de
`request.ip`; detrás de un balanceador, configura `trust proxy` en `main.ts` con una variable
`TRUST_PROXY_HOPS` (por defecto 0). Esquemas Zod en `api/schemas.ts` con claves en español.

**Zonas.** `ListZones` lee `identidad.zonas` con `KYSELY` (`id`, `nombre`, `distrito`).
`ChooseZone.execute(actor, zoneId)` corre
`UPDATE identidad.usuarios SET zona_id = $1, actualizado_en = now() WHERE id = $2 AND zona_id IS NULL`.
Si no actualiza ninguna fila y el vecino ya tiene zona, lanza
`BusinessRuleViolation('zona_ya_elegida', 'Ya elegiste tu zona.', 'conflict')`. Luego emite un
token de acceso nuevo con `TokenService.issueAccess` (con `sid` desde la Parte 2), para que el
celular sincronice el muro de su zona de inmediato. Un vecino de nivel 0 ya puede ver su zona;
para publicar sigue necesitando nivel 1.

La sesión de desarrollo (`POST /v1/dev/sesiones`) se queda: la usa la app hasta que el Lote A
cambie a OTP.

### 1.7 Pruebas y verificación

- Unitarias (`request-otp.spec.ts`, `verify-otp.spec.ts`) con el repositorio en memoria,
  `FakeOtpProvider` y un reloj fijo: código correcto, vencido, reutilizado, 5 errores y bloqueo,
  y límites por teléfono e IP.
- Integración (`test/integration/otp.int-spec.ts`): obtén el doble con
  `app.get(OTP_PROVIDER) as FakeOtpProvider`. Casos: teléfono nuevo y existente reciben el mismo
  202; verificar crea el usuario con nivel 0 (compruébalo con SQL); reusar el código da 401; tras
  5 códigos errados se recibe 429 con `Retry-After`; la cuarta solicitud en 15 minutos da 429.
  Ninguna prueba envía SMS reales.
- Zonas (`test/integration/zones.int-spec.ts`): la lista no trae el polígono; un vecino nuevo
  elige la zona piloto y `GET /v1/sync/credenciales` emite un token con `zona`; elegirla otra vez
  da 409 `zona_ya_elegida`.
- Tarea 1.4: una prueba manual con Twilio documentada en `docs/fase-0/evidencias/otp.md`, con
  las credenciales fuera del repo.

**Aceptación:** todos los escenarios de `specs/identidad/inicio-de-sesion/spec.md` cubiertos por
pruebas, y `npm run verify` y `npm run test:integration` en verde.

---

## Parte 2 · Sesiones revocables

Rama: `lote-b/parte-2-sesiones` · Tareas 2.1–2.4 · Spec: `specs/identidad/sesiones/spec.md`

### 2.1 Contrato

- Al esquema `Sesion` agrega `refreshToken: string` y `refreshExpiraEn: date-time`. Es un cambio
  aditivo y lo devuelve `POST /v1/auth/otp/verificar`.
- `POST /v1/auth/refrescar` (público): cuerpo `{ refreshToken }` → 200 `Sesion` con el par nuevo.
  401 `sesion_invalida` o `sesion_revocada`.
- `POST /v1/auth/cerrar-sesion` (con token) → 204.
- `POST /v1/auth/sesiones/revocar` (con token) → 204: revoca todas las sesiones del vecino.
- Documenta en `GET /v1/sync/credenciales` la respuesta 401 `sesion_revocada`.

### 2.2 Migración `identidad.sesiones`

`202611070200_identidad_sesiones.ts`:

```sql
CREATE TABLE identidad.sesiones (
  id            uuid        PRIMARY KEY DEFAULT uuidv7(),
  usuario_id    uuid        NOT NULL REFERENCES identidad.usuarios(id),
  familia_id    uuid        NOT NULL,
  refresh_hash  text        NOT NULL UNIQUE,
  dispositivo   text        CHECK (char_length(dispositivo) <= 80),
  creada_en     timestamptz NOT NULL DEFAULT now(),
  expira_en     timestamptz NOT NULL,
  rotada_en     timestamptz,
  revocada_en   timestamptz,
  motivo        text        CHECK (motivo IN ('cierre', 'revocacion_total', 'reutilizacion'))
);
CREATE INDEX sesiones_usuario_activas_idx ON identidad.sesiones (usuario_id) WHERE revocada_en IS NULL;
CREATE INDEX sesiones_familia_idx ON identidad.sesiones (familia_id);
```

Configuración: `REFRESH_TOKEN_SECRET` (32 caracteres o más, también lo genera `dev:keys`) y
`REFRESH_TOKEN_DAYS` (por defecto 30).

### 2.3 Tokens

- El refresh token es opaco: `randomBytes(32).toString('base64url')`. Solo se guarda
  `HMAC-SHA256(REFRESH_TOKEN_SECRET, token)` en `refresh_hash`.
- El token de acceso lleva el claim **`sid`** con el `familia_id`. Cambios en el núcleo:
  `Actor` gana `sessionId?: string`; `TokenService.issueAccess(actor)` firma `sid` si
  `actor.sessionId` existe; `actorFromClaims` lo lee. Actualiza `token.service.spec.ts`.

### 2.4 Casos de uso

- `CreateSession` (lo llama `VerifyOtp` al final): crea la fila con un `familia_id` nuevo y
  devuelve el par (acceso con `sid` + refresh).
- `RefreshSession.execute(refreshToken)`, todo dentro de `unitOfWork.run`:
  1. Busca por hash con `FOR UPDATE`. Si no existe → `sesion_invalida`.
  2. `revocada_en` no nulo → `sesion_revocada`.
  3. `rotada_en` no nulo → **reutilización**: revoca toda la familia
     (`motivo = 'reutilizacion'`) y el resultado es `reused`.
  4. Vencida → `sesion_invalida`.
  5. Caso normal: marca `rotada_en = now`, inserta la fila nueva con el mismo `familia_id` y
     vuelve a leer al usuario desde la base (así un cambio de nivel, rol o zona entra en el token
     nuevo). Si el usuario ya no existe → `sesion_revocada`.
  6. **Fuera de la transacción** lanza `AuthenticationFailure` según el resultado (la misma trampa
     de la Parte 1: la revocación por reutilización tiene que quedar guardada).
- `LogOut.execute(actor)`: revoca la familia `actor.sessionId` con `motivo = 'cierre'`. Sin `sid`
  (sesión de desarrollo) no hace nada.
- `RevokeAllSessions.execute(actor)`: revoca todas las sesiones activas del usuario con
  `motivo = 'revocacion_total'`.
- `IssueCredentials.forSync(actor)` (cambia la firma): si `actor.sessionId` existe y esa familia
  no tiene ninguna sesión activa, lanza `AuthenticationFailure('sesion_revocada')`.

Decisión documentada: el token de acceso sigue valiendo hasta que vence (15 minutos o menos). La
revocación corta los tokens nuevos y las credenciales de sincronización. **Riesgo para el
Lote A:** sin ventana de gracia, si la red pierde la respuesta de `refrescar` y el celular
reintenta con el refresh viejo, se detecta como reutilización y se cierra la sesión. El cliente
debe serializar las renovaciones y guardar el refresh nuevo antes de usarlo. Anótalo en el
informe.

### 2.5 Pruebas

Integración (`test/integration/sessions.int-spec.ts`): OTP → refrescar → el refresh viejo da 401
y revoca la familia → el refresh nuevo también da 401. Cerrar sesión → `GET /v1/sync/credenciales`
da 401 `sesion_revocada`. Revocar todo desde el dispositivo B → el dispositivo A ya no refresca
ni obtiene credenciales. Unitarias de `RefreshSession` con un reloj fijo y un repositorio en
memoria.

---

## Parte 3 · Roles y niveles de confianza

Rama: `lote-b/parte-3-roles` · Tareas 3.1–3.3 · Spec: `specs/identidad/roles-y-confianza/spec.md`

1. En `src/shared/auth/decorators.ts`: `RequireTrustLevel(level: number)` y
   `RequireRole(...roles: Role[])` con `SetMetadata` (`TRUST_LEVEL_METADATA`, `ROLES_METADATA`).
2. `src/shared/auth/authorization.guard.ts` (`AuthorizationGuard`): lee la metadata con
   `reflector.getAllAndOverride`; si la ruta es `@Public()` o no tiene metadata, deja pasar. Si
   falta nivel: `BusinessRuleViolation('nivel_de_confianza_insuficiente', 'Para hacer esto
   necesitas nivel N de confianza.', 'forbidden', { nivelActual, nivelRequerido })`. Si falta
   rol: `BusinessRuleViolation('rol_requerido', …, 'forbidden', { rolesRequeridos })`. Con varios
   roles basta tener uno; si también se exige nivel, deben cumplirse ambas condiciones. La
   metadata del método sobrescribe la de su clase. El rol `administrador` **no** reemplaza a otros
   roles de forma implícita.
3. Regístralo en `shared.module.ts` como un segundo `APP_GUARD`, **después** de `AuthGuard`: Nest
   ejecuta los guards globales en el orden en que se registran.
4. Aplícalo: `POST /v1/publicaciones` y `POST /v1/publicaciones/{id}/tomar` con
   `@RequireTrustLevel(1)`. La regla del dominio de publicar se mantiene como segunda defensa.
   Documenta el nivel en el contrato con `x-nivel-minimo: 1` y en la descripción de cada ruta.
5. Los cambios de nivel, rol o zona entran en el siguiente token o en las siguientes credenciales
   de sincronización. Esta entrega lo verifica con `IssueCredentials.forSync`, que relee al usuario
   desde la base. `RefreshSession` pertenece a la Parte 2 y todavía no existe en esta rama: deberá
   reutilizar esa lectura al implementarse; aquí no se implementa ni se prueba el refresh.
6. Pruebas: unitarias del guard con un controlador de prueba, como en
   `idempotency.interceptor.spec.ts` (sin metadata, nivel suficiente o insuficiente, rol presente
   o ausente, ambos a la vez). De punta a punta: `dario` (nivel 0) intenta tomar un favor y recibe
   403 con `nivelRequerido = 1`.

---

## Parte 4 · Eventos y trabajos (pg-boss + relay del outbox + workers)

Rama: `lote-b/parte-4-trabajos` · Tareas 4.1–4.4 · Spec: `specs/plataforma/eventos-y-trabajos/spec.md`

### 4.1 Adaptador pg-boss

- `npm i pg-boss` (al 7-nov-2026 la última es la 12.x). **Lee el README de la versión
  instalada:** desde la v10 hay que crear cada cola con `createQueue` antes de usarla, y
  `work(name, async ([job]) => …)` recibe un arreglo.
- `src/shared/queues/job-queue.pgboss.ts` → `PgBossJobQueue implements JobQueue` con
  `OnModuleInit` y `OnModuleDestroy`: `new PgBoss({ connectionString: DATABASE_URL, schema: 'colas' })`.
  En el proceso de la API, sin mantenimiento ni programación (opciones de supervisión y
  `schedule` apagadas); en los workers, encendidas.
- Mapeo de `JobOptions`: `priority` → `critical = 20`, `normal = 10`, `low = 0` (confirma en el
  README que un número mayor se procesa antes); `retries` → `retryLimit` (por defecto 5) con
  `retryBackoff: true`; `singletonKey` → `singletonKey`; `delaySeconds` → `startAfter`.
- Cada cola se crea con su cola de fallidos `<nombre>.fallidos` (`deadLetter`).
- Configuración `JOB_QUEUE_DRIVER = 'memory' | 'pgboss'`: `pgboss` fuera de las pruebas y
  `memory` en las unitarias. En `shared.module.ts`, `JOB_QUEUE` se elige con `useFactory`.

### 4.2 Relay del outbox

`src/shared/outbox/outbox-relay.ts` → `OutboxRelay.runOnce(batchSize = 100)`:

```sql
SELECT id, modulo, tipo, agregado_id, carga, ocurrido_en
FROM compartido.outbox
WHERE publicado_en IS NULL
ORDER BY ocurrido_en, id
LIMIT $1
FOR UPDATE SKIP LOCKED
```

Por cada fila: `jobQueue.enqueue(row.tipo, { eventoId, modulo, agregadoId, carga, ocurridoEn },
{ singletonKey: row.id, priority: row.modulo === 'emergencias' ? 'critical' : 'normal' })`. Luego
`UPDATE … SET publicado_en = now(), intentos = intentos + 1 WHERE id = ANY($ids)` en la misma
transacción. Si `enqueue` falla, suma `intentos` sin publicar y sigue con la siguiente fila.

La entrega es **al menos una vez**: si el proceso muere entre el `send` y el commit, el evento se
vuelve a publicar. Lo cubren el `singletonKey` y los manejadores idempotentes. Si la versión de
pg-boss permite enviar dentro de una transacción externa, úsalo para que el envío y la marca sean
atómicos y anótalo en el informe.

### 4.3 Proceso de workers

- `src/workers/main.ts` y `src/workers/workers.module.ts`:
  `NestFactory.createApplicationContext(WorkersModule)`, que importa `AppConfigModule`,
  `DatabaseModule`, `SharedModule` y los módulos que registran manejadores.
- `src/shared/queues/job-handler.registry.ts` (`JobHandlerRegistry`): los módulos llaman a
  `register(name, handler)` en su `onModuleInit`, y el proceso de workers llama a
  `startAll(jobQueue)` después de iniciar.
- El relay corre cada segundo, sin solaparse (no se lanza otra vuelta si la anterior sigue).
- Limpieza programada (`plataforma.limpieza_diaria`, todos los días a las 04:00 de
  America/Lima): `PostgresIdempotencyStore.deleteExpired(now)` y
  `DELETE FROM compartido.outbox WHERE publicado_en < now() - interval '30 days'`.
- Scripts en `package.json`: `"start:workers": "node dist/workers/main.js"` y
  `"start:workers:dev": "tsx watch src/workers/main.ts"`.
- Cierre ordenado: `enableShutdownHooks()` y `boss.stop()`.
- En `.dependency-cruiser.cjs`, la regla `only-app-module-composes` debe aceptar también
  `^src/workers/` como raíz de composición.

### 4.4 Contrato del trabajo de avisos (para el Lote C)

`src/modules/notificaciones/application/send-notification.job.ts`, exportado por
`notificaciones/index.ts`:

```ts
export const SEND_NOTIFICATION_JOB = 'notificaciones.enviar_aviso';

/** JSON keys are a contract with the workers and stay in Spanish. */
export interface SendNotificationJob {
  /** Same avisoId = a single push, even if the job is delivered twice. */
  readonly avisoId: string;
  readonly destino:
    | { readonly tipo: 'usuario'; readonly usuarioId: string }
    | { readonly tipo: 'zona'; readonly zonaId: string };
  readonly plantilla: 'favor_tomado' | 'aviso_de_zona';
  /** Ids only; never names, locations or health data. */
  readonly datos: Readonly<Record<string, string>>;
}
```

Documenta en `docs/fase-0/trabajos.md` cada trabajo: nombre, carga, prioridad, reintentos, quién
lo produce y quién lo consume. Los eventos actuales (`solidaridad.publicacion_creada` y
`solidaridad.favor_tomado`) salen del outbox con su mismo nombre. El Lote C escribe el manejador
que convierte `solidaridad.favor_tomado` en `notificaciones.enviar_aviso`.

### 4.5 Pruebas

Integración con pg-boss en la base de pruebas (esquema `colas_pruebas` propio):

- **Prioridad:** 1 000 trabajos normales pendientes + 1 crítico, con un worker de a uno → el
  crítico se procesa primero.
- **Reintentos y fallidos:** un manejador que falla siempre → tras 5 intentos el trabajo está en
  `<nombre>.fallidos` con el error.
- **Relay:** 200 eventos en el outbox y dos relays en paralelo → cada evento se encola una sola
  vez y todos quedan con `publicado_en`. Reiniciar con pendientes → se publican al volver.
- **Limpieza:** se borran las claves vencidas y el outbox publicado hace más de 30 días.

---

## Parte 5 · Muro completo

Rama: `lote-b/parte-5-muro` · Tareas 5.1–5.4 · Spec: `specs/solidaridad/muro-de-favores/spec.md`

### 5.1 Contrato

- `GET /v1/publicaciones` con los parámetros `lat`, `lng` (obligatorios), `radio` (metros, de 100
  a 5 000, por defecto 2 000), `cursor` (opaco) y `limite` (de 1 a 50, por defecto 20) → 200
  `PaginaDePublicaciones { datos: PublicacionCercana[], siguienteCursor: string | null }`, donde
  `PublicacionCercana` es `Publicacion` + `distanciaMetros`.
- `POST /v1/publicaciones/{id}/cancelar` y `POST /v1/publicaciones/{id}/resolver`, con cuerpo
  `{ versionVista }`, ambas con `@Idempotent()` → 200 `Publicacion`. Errores: 403, 404 y 409.
- En `POST /v1/publicaciones` agrega el 429 `limite_diario_alcanzado`.

### 5.2 Dominio (`domain/post.ts`)

- `cancel(actorId, seenVersion, now)`: solo el autor (si no, `no_eres_el_autor`, forbidden);
  solo si está `abierta` (si no, `no_se_puede_cancelar`, conflict, con `estadoActual`); verifica
  la versión (`VersionConflict`) → `cancelada`, versión + 1, evento
  `solidaridad.publicacion_cancelada`. Si el autor repite la acción sobre algo ya cancelado,
  devuelve `'already_cancelled'` sin error.
- `resolve(actorId, seenVersion, now)`: el autor o quien tomó el favor (si no,
  `no_participas_en_este_favor`, forbidden); solo si está `en_curso` (si no, `favor_no_en_curso`,
  conflict); verifica la versión → `resuelta`, versión + 1, evento `solidaridad.favor_resuelto`.
  Repetirlo devuelve `'already_resolved'`.
- Los casos de uso `CancelPost` y `ResolveFavor` copian el patrón de `TakeFavor`, incluida la
  carrera entre la lectura y la escritura y el registro en el outbox.

### 5.3 Búsqueda por cercanía

`findNearby` en el repositorio Kysely, como lectura con `KYSELY` (sin transacción):

```sql
WITH cercanas AS (
  SELECT p.*, ST_Distance(p.ubicacion, ST_SetSRID(ST_MakePoint($lng, $lat), 4326)::geography) AS distancia
  FROM solidaridad.publicaciones p
  WHERE p.estado = 'abierta' AND p.eliminado_en IS NULL AND p.ubicacion IS NOT NULL
    AND (p.vence_en IS NULL OR p.vence_en > now())
    AND ST_DWithin(p.ubicacion, ST_SetSRID(ST_MakePoint($lng, $lat), 4326)::geography, $radio)
)
SELECT * FROM cercanas
WHERE ($cursorDistancia IS NULL OR (distancia, id) > ($cursorDistancia, $cursorId))
ORDER BY distancia, id
LIMIT $limite + 1
```

El índice GiST `publicaciones_ubicacion_gix` ya existe. El cursor es `base64url(JSON { d, id })`.
Si vuelve una fila extra, hay página siguiente. **Privacidad:** `distanciaMetros` se redondea a
múltiplos de 50 m para que no se pueda triangular, y la ubicación de quien busca no se guarda.

### 5.4 Límite diario

Configuración `MAX_POSTS_PER_DAY` (por defecto 10). En `PublishPost`, **después** de comprobar
que el id no existe (un reintento del mismo id nunca debe chocar con el límite), cuenta las
publicaciones del autor en las últimas 24 horas. Si llegó al máximo:
`RateLimitExceeded('limite_diario_alcanzado', 'Llegaste al límite de publicaciones de hoy.
Podrás publicar de nuevo más tarde.', segundos hasta que salga la más antigua)`.

### 5.5 Pruebas

Unitarias: la matriz completa de `cancel` y `resolve`. Integración con PostGIS: tres
publicaciones a unos 500 m, 1,5 km y 3 km de un punto de la zona piloto; un radio de 2 km
devuelve las dos primeras en orden; `limite=1` con cursor recorre ambas páginas. Cancelar y
resolver de punta a punta con versiones viejas (409). Para el límite usa un usuario nuevo creado
por OTP (súbele el nivel a 1 con SQL en la prueba) y `MAX_POSTS_PER_DAY=3` en
`createTestApp`: la cuarta publicación da 429 con `Retry-After`.

---

## Parte 6 · Capacidad

Rama: `lote-b/parte-6-capacidad` · Tareas 6.1–6.4 · Spec: `specs/plataforma/capacidad/spec.md`

1. **Escenario k6** en `backend/test/load/emergency-peak.js` (actualiza la ruta en la tarea 6.1).
   Unas 2 500 peticiones por segundo durante 10 minutos con `constant-arrival-rate`:
   - `lecturas`, unas 1 750 por segundo: `GET /v1/publicaciones` por cercanía y `GET /v1/salud`;
   - `escrituras`, unas 500 por segundo: `POST /v1/publicaciones` con `Idempotency-Key`, el 10 %
     repitiendo la misma clave;
   - `reconexion`, unas 250 por segundo con picos (`ramping-arrival-rate`): `GET /v1/sync/credenciales`
     simulando que miles de celulares vuelven a tener señal a la vez.
   - Umbrales de ejemplo, a acordar con el equipo (decisión abierta 6): `http_req_failed < 1 %`,
     p95 de lecturas < 300 ms, de escrituras < 500 ms y de credenciales < 300 ms. Si se superan,
     k6 termina con error.
2. **Tokens para la carga:** `scripts/generate-load-tokens.ts` crea N usuarios de carga en la base
   de destino y escribe sus tokens de acceso en un archivo local que no se sube (agrega el patrón
   al `.gitignore`). Nunca uses la sesión de desarrollo en staging.
3. **Instrumentación mínima:** `src/shared/observability/request-id.middleware.ts` (cabecera
   `x-request-id`: la toma si viene o genera un UUIDv7, la devuelve y la incluye en los logs JSON
   y en el `instance` de Problem Details). `GET /v1/operacion/metricas` con
   `@RequireRole('administrador')` en JSON: resultados de la idempotencia (nueva, repetida, en
   curso, huella distinta), eventos pendientes del outbox y la edad del más antiguo, y la
   profundidad de cada cola. Si se adopta OpenTelemetry, va con su ADR.
4. **Corrida de humo local:** `k6 run --vus 10 --duration 30s` contra `http://localhost:3000`.
5. **Informe** en `docs/fase-0/evidencias/capacidad.md`: entorno (tamaño de staging), commit,
   escenario, p95 y tasa de error por escenario, profundidad de la cola crítica en el tiempo y
   conclusiones. La corrida completa es contra staging, no contra una laptop.

---

## 8. Puntos de contacto con otros lotes

| Con | Qué | Regla |
|---|---|---|
| Lote A (app offline) | Contrato de `/v1/auth/*`, claim `sid`, 401 de credenciales tras revocar | El contrato se acuerda en el primer commit de la parte; A prueba con un HTTP falso mientras tanto |
| Lote C (avisos) | `SEND_NOTIFICATION_JOB` y `SendNotificationJob` (Parte 4.4), `JobHandlerRegistry` | B lo define; C escribe los manejadores |
| Todos | `src/shared/**` (errores, auth, colas) | Cambios mínimos, con pruebas, explicados en el informe |
| Todos | `contracts/openapi.yaml`, `backend/package.json` | Commits pequeños; rebase antes de entregar |

## Fuera de alcance

Validación de DNI (nivel 3), consola web (Fase 2), Valkey y BullMQ (Fase 3), extracción de
microservicios y cambios en la app Flutter.

## 9. Informe de entrega (descripción del PR de cada parte)

```text
Lote B · Parte N · <tema>
Rama: lote-b/parte-N-<tema> · PR: #<número>
Qué cambió: …
Contrato: rutas y esquemas nuevos o cambiados
Migraciones: …
Variables nuevas (.env.example): …
Verificación: npm run verify ✔ · test:integration ✔ (N pruebas) · redocly ✔ · openspec ✔ · boundaries ✔
Tareas marcadas: N.1 … N.k
Puntos de contacto tocados: …
Riesgos o pendientes: …
```

## 10. Definición de terminado del lote

Las 6 partes aprobadas e integradas en `main`, todos los escenarios de `specs/` cubiertos por
pruebas, la evidencia de capacidad en `docs/fase-0/evidencias/capacidad.md` y el change listo
para archivarse cuando el Lote A apruebe la última entrega.
