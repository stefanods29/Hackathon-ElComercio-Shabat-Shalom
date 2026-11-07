# Lote A · Núcleo offline e integración

| Dato | Valor |
|---|---|
| Dificultad | ★★★★ Muy alta (el más complejo de la Fase 0) |
| Responsable | Stefano (stefanods29). Además revisa e integra las entregas de B, C y D |
| Área | `app/lib/core/sync/`, `app/lib/core/storage/`, `app/lib/features/solidaridad/data/`, `app/lib/features/emergencias/`, `app/pubspec.yaml`, `infra/powersync/`, `backend/src/modules/emergencias/` |
| Change de OpenSpec | `openspec/changes/lote-a-nucleo-offline/` (proposal, design, specs, tasks) |
| Issue de GitHub | #1 · Lote A · Núcleo offline, integración y revisión |
| Partes | 6, en orden |

## Estado del lote

**17 de 28 tareas verificadas en la rama `fase0-a`.** Las fracciones de la tabla corresponden
a las casillas del [checklist de OpenSpec](../../../openspec/changes/lote-a-nucleo-offline/tasks.md).
La verificación en la rama y la integración en `main` son hitos separados.

| Parte | Tareas | Terminado y comprobado | Pendiente para cerrar |
| --- | --- | --- | --- |
| 1 · PowerSync | 4/5 | La API entrega credenciales renovables y el muro sincroniza y se puede abrir sin señal. Verificado en un Redmi Note 13. | CI de la entrega. |
| 2 · Cifrado y sesión | 4/6 | SQLite cifrado, caducidad de casos, purga por revocación y cierre local de la sesión de prueba. [Pruebas de purga](../evidencias/purga.md). | Conexión con la cuenta real de los Lotes B y D, compilación en iOS y CI. |
| 3 · Cola de subida | 4/6 | Publicar y tomar quedan en la cola cifrada. En la prueba de conflicto se conservó el motivo del rechazo y se envió la siguiente acción. | Verificar las pantallas del Lote D con el repositorio real y pasar CI. |
| 4 · Casos sensibles | 4/5 | Solo se descarga el caso solicitado por el personal asignado. El Redmi borró el caso al reasignarlo. [Prueba de purga](../evidencias/purga.md). | CI de la entrega. |
| 5 · Pruebas de campo | 1/4 | Purga comprobada en Android. En una prueba parcial de carga, 500 publicaciones sintéticas llegaron desde el Redmi sin pérdidas ni duplicados. [Prueba de carga](../evidencias/cola-offline.md). | Completar la matriz de campo en Android e iOS, medir segundo plano y probar el conflicto con dos celulares y la pantalla del Lote D. |
| 6 · Integración | 0/2 | El entorno local y los resultados de los componentes ya están disponibles para la integración. | Entregas aprobadas de B, C y D, flujo completo y CI en `main`. |

---

## 0. Antes de empezar

### 0.1 Por qué este lote es el primero en riesgo

Si la cola offline pierde o duplica acciones, o si un dato sensible llega al celular equivocado,
el producto falla justo cuando más se necesita. Este lote cambia los dobles en memoria de la app
por **PowerSync** con una base local **cifrada** mediante proveedores de la app y demuestra con
dispositivos reales los criterios de la sección 13.1.

### 0.2 Lo que ya está hecho (cimientos en `main`)

| Pieza | Dónde | Qué hace |
|---|---|---|
| Estados de envío | `app/lib/core/submissions/` | `SubmissionStatus` (*Guardado en tu celular*, *Enviado*, *No se pudo completar*), `Submission.recordAttempt`, `nextStatus` |
| Clasificación de respuestas | `app/lib/core/network/classify_response.dart` | 2xx → `Accepted`; 4xx definitivo → `Rejected(motivo)`; red caída, 5xx, 408 o 429 → `TransientFailure` |
| Reintentos | `app/lib/core/submissions/retry_policy.dart` | Espera exponencial con *full jitter* |
| Puertos y dobles | `core/sync/sync_service.dart`, `features/solidaridad/domain/post_repository.dart` | `SyncService` + `FakeSyncService`; `PostRepository` + `InMemoryPostRepository` |
| Almacén seguro | `app/lib/core/storage/secure_store.dart` | `SecureStore` sobre Keychain/Keystore |
| Proveedores | `app/lib/core/di/providers.dart`, `features/solidaridad/data/providers.dart` | `syncServiceProvider` y `postRepositoryProvider`: se sobreescriben con la versión real |
| API | `backend/` | `POST /v1/publicaciones` y `POST /v1/publicaciones/{id}/tomar` idempotentes; `GET /v1/sync/credenciales` (token con audiencia `powersync` y claims `sub` y `zona`); JWKS en `/.well-known/jwks.json` |
| Sync Streams | `infra/powersync/sync-config.yaml` | `mi_zona`, `muro_de_mi_zona` y `mis_publicaciones`, validados con `npm run sync:validate` |
| Infraestructura | `infra/docker-compose.yml` | PostgreSQL 18 + PostGIS 3.6 con replicación lógica, PowerSync en `:8080` (valida con el JWKS de la API en `:3000`) y CDN en `:8090` |
| App en Windows | `app/` | `flutter analyze` sin avisos y 28 pruebas en verde; `android/` e `ios/` generadas |

### 0.3 Lo que falta

Las 6 partes de abajo. Cada una termina con la app y el backend compilados y depurados.

### 0.4 Reglas

1. **Integración mediante proveedores.** La versión real entra sobreescribiendo proveedores de
   Riverpod. El modo de depuración incluye un botón para probar el cierre local.
2. **Toda acción del vecino es un comando con su `Idempotency-Key`**, que se reintenta sin duplicar.
3. **Un rechazo definitivo nunca bloquea la cola:** se completa y va a "acciones por revisar".
4. **Datos sensibles nunca en streams automáticos**, solo bajo demanda y para quien está asignado.
5. Código en inglés; textos, contrato JSON, tablas y documentación en español.
6. Una parte, una rama (`lote-a/parte-<n>-<tema>`) y un PR; compilar y depurar antes de entregar.

### 0.5 Preparar el entorno

```bash
git clone https://github.com/stefanods29/Hackathon-ElComercio-Shabat-Shalom.git
cd Hackathon-ElComercio-Shabat-Shalom/infra && docker compose up -d --wait postgres cdn
cd ../backend && npm ci && npm run dev:keys && npm run db:migrate && npm run db:seed
docker compose -f ../infra/docker-compose.yml up -d --wait powersync
npm run start:dev
```

En otra terminal, desde la raíz del repositorio:

```bash
cd app && flutter pub get && flutter gen-l10n
flutter run --debug --dart-define=DEV_SYNC=true --dart-define=API_BASE_URL=http://10.0.2.2:3000 --dart-define=POWERSYNC_URL=http://10.0.2.2:8080
```

`DEV_SYNC` activa la conexión real en depuración con la cuenta de prueba de Beto. Las
direcciones `10.0.2.2` son para el emulador Android. Para un celular físico, usa la
dirección de la PC en la red local en ambas opciones y conecta ambos equipos a esa red.

Necesitas Docker Desktop, Node 26, Flutter 3.47.9, Android SDK 36 con el NDK 28.2.13676358, un
Android real de gama baja y un iPhone (o los builds de iOS de la CI con TestFlight).

### 0.6 Cómo encaja una acción sin conexión

```mermaid
sequenceDiagram
  autonumber
  actor V as Vecino
  participant R as PowerSyncPostRepository
  participant DB as SQLite cifrado
  participant C as Conector (uploadData)
  participant API as API /v1
  V->>R: Tomar favor (versión vista = 1)
  R->>DB: Transacción local: cambio optimista + comando + envío "guardado en tu celular"
  C->>DB: getNextCrudTransaction()
  C->>API: POST /v1/publicaciones/{id}/tomar + Idempotency-Key del comando
  alt 2xx
    C->>DB: envío = enviado; complete()
  else 4xx definitivo
    C->>DB: envío = no se pudo completar + motivo; revertir; complete()
  else red caída / 5xx / 408 / 429
    C-->>C: lanzar error → PowerSync reintenta con espera
  end
  API-->>DB: el cambio real vuelve por Sync Streams y reemplaza al optimista
```

---

## Parte 1 · PowerSync de punta a punta

Rama: `lote-a/parte-1-powersync` · Tareas 1.1–1.5

El 7 de noviembre de 2026 se verificó la tarea 1.1 en Windows. La API y el servidor de
archivos respondieron con HTTP 200. Una sesión de prueba de Beto recibió la zona piloto
y una publicación creada por Ana a través de `POST /sync/stream`, con el punto de
sincronización confirmado. Pasaron las 36 pruebas del backend y las 17 de integración.

En el emulador con Android 36 se instaló el APK de depuración y se comprobó que una
publicación descargada sigue visible al cerrar y reabrir la app en modo avión.
En un Redmi Note 13 con Android 15 se verificó la descarga del muro por PowerSync mediante
USB y se volvió a abrir la app en modo avión. El muro conservó la publicación de prueba
y mostró «Sin conexión».

1. **Infraestructura viva:** con `docker compose up -d`, la API y la semilla corriendo, revisa con
   `docker compose logs -f powersync` que el servicio replica `identidad.zonas` y
   `solidaridad.publicaciones` sin errores de permisos ni de esquema.
2. **Paquete y esquema local:** `flutter pub add powersync` (2.x). En
   `lib/core/sync/local_schema.dart` define las tablas:
   - `zonas` y `publicaciones`, con las mismas columnas que sus streams;
   - `comandos` (*insert-only*): `tipo`, `recurso_id`, `cuerpo` (JSON) y `clave_idempotencia`;
   - `envios` (*local-only*): estado visible de cada comando, intentos y motivo del rechazo.
   Comprueba con una prueba de integración en dispositivo (`integration_test/`) que la base abre.
3. **Conector** `lib/core/sync/vecinal_connector.dart` (`PowerSyncBackendConnector`):
   `fetchCredentials()` llama a `GET /v1/sync/credenciales` con el token de acceso y devuelve
   `endpoint`, `token` y `expiraEn`. PowerSync lo vuelve a pedir antes de que venza. Prueba con un
   HTTP falso: credenciales correctas, 401 y red caída.
4. **`PowerSyncSyncService implements SyncService`**: traduce el estado de PowerSync (conectado,
   última sincronización y pendientes de subir) a `SyncStatus` y sobreescribe
   `syncServiceProvider`. Verifica en un Android real que llegan las publicaciones de la zona.
5. **Compilar y depurar:** `flutter analyze`, `flutter test`, el APK y la CI en verde.

## Parte 2 · Cifrado local, purga e inicio de sesión real

Rama: `lote-a/parte-2-cifrado-y-purga` · Tareas 2.1–2.6

1. **Base cifrada:** genera una clave aleatoria de 32 bytes (`Random.secure()`), guárdala con
   `SecureStore` y abre la base con `EncryptionOptions`. En `pubspec.yaml` agrega
   `hooks: user_defines: sqlite3: source: sqlite3mc` (ADR-0004). Prueba: la base no abre con otra
   clave.
2. **Cerrar sesión:** desconecta y borra la base local (`disconnectAndClear` o el nombre que use la
   versión instalada), borra la clave y vuelve al inicio. Prueba: no queda ningún dato.
3. **Caducidad local** de los datos sensibles con el reloj inyectable (`clockProvider`): se borran
   al vencer su plazo (24 h propuestas, decisión abierta 6) aunque el celular siga sin conexión.
   El caso abierto se guarda en una base cifrada con su propia clave y vence en `vence_en`.
   Se revisa al iniciar, al volver a la app y mientras la app está activa.
4. **Sesión revocada:** si `GET /v1/sync/credenciales` responde 401 `sesion_revocada`, se borra la
   base local.
5. **Inicio de sesión real:** implementa el `AuthRepository` del Lote D (Parte 5) contra la API del
   Lote B: tokens en `SecureStore`, `getToken` con renovación **serializada** (una sola a la vez,
   guardando el refresh nuevo antes de usarlo) y cierre de sesión (API, borrado local y baja del
   token de avisos del Lote C). Sobreescribe `authRepositoryProvider`.
6. **Compilar y depurar** en Android e iOS.

## Parte 3 · Cola de subida con estados, reintentos y rechazos

Rama: `lote-a/parte-3-cola-de-subida` · Tareas 3.1–3.6

Con la infraestructura y la API levantadas en la PC, la prueba siguiente simula dos vecinos
que toman el mismo favor sin conexión y comprueba que el rechazo del segundo no bloquea el
envío de su siguiente publicación.

```bash
flutter test --dart-define=LIVE_POWERSYNC=true test/features/solidaridad/powersync_wall_live_test.dart
```

En el Redmi Note 13 se interrumpió el acceso de la app a la API y PowerSync por USB. Al
tomar un favor se mostró «Guardado en tu celular». Ese estado sobrevivió al cierre
forzado y PostgreSQL conservó el favor abierto hasta reconectar. Al restablecer el
acceso, la app mostró «Enviado» y el servidor confirmó el favor en curso, versión 2.

1. **`PowerSyncPostRepository implements PostRepository`**
   (`features/solidaridad/data/powersync_post_repository.dart`): `watchWall()` con consultas
   reactivas de SQLite (la zona del vecino, de la más nueva a la más antigua), combinando cada
   publicación con el estado de su último envío.
2. **Publicar y tomar favor:** en una sola transacción local, el cambio optimista, el comando y su
   envío en *Guardado en tu celular*.
3. **`uploadData`:** toma la siguiente transacción, envía cada comando a su endpoint con su
   `Idempotency-Key` y clasifica la respuesta con `classifyResponse`:
   - `Accepted` → envío *Enviado* y `complete()`;
   - `Rejected` → envío *No se pudo completar* con el motivo, revierte el cambio optimista y
     `complete()`, para no bloquear la cola;
   - `TransientFailure` → lanza el error y PowerSync reintenta con espera.
4. **"Acciones por revisar":** `watchActionsToReview()` lee los envíos rechazados con su motivo.
   Prueba de conflicto: dos vecinos toman el mismo favor contra la API local.
5. **Sobreescribe `postRepositoryProvider`** y comprueba que las pantallas del Lote D funcionan sin
   cambios.
6. **Compilar y depurar.**

## Parte 4 · Datos sensibles bajo demanda

Rama: `lote-a/parte-4-datos-sensibles` · Tareas 4.1–4.5

El servicio exige una suscripción explícita al caso, una asignación activa y el rol de
brigadista o coordinador. La prueba de acceso se ejecuta con `npm test` en el backend.
La [evidencia en Android](../evidencias/purga.md) muestra la caducidad y el borrado tras reasignar.

1. **Migraciones mínimas** del módulo `emergencias`: `emergencias.pedidos_ayuda` y
   `emergencias.asignaciones`. Se agregan a la publicación `powersync` con `SELECT` solo para
   `powersync_rol`. Verifica con `npm run test:integration`.
2. **Stream bajo demanda `caso_asignado`** en `sync-config.yaml`: sin `auto_subscribe`, filtra por
   `subscription.parameter('pedido_id')` y exige una asignación activa del usuario autenticado.
   Verifica con `npm run sync:validate`.
3. **Pruebas de acceso automatizadas:** un usuario no asignado recibe 0 filas; el asignado, solo su
   caso. Una prueba que falla si alguien agrega un stream automático con tablas sensibles.
4. **Revocación:** al reasignar el caso, el detalle se borra del celular anterior (evidencia en
   dispositivo real).
5. **Compilar y depurar** backend y app.

## Parte 5 · Pruebas de campo (sección 13.1)

Rama: `lote-a/parte-5-pruebas-de-campo` · Tareas 5.1–5.4. Cada prueba deja su evidencia en
`docs/fase-0/evidencias/` con el formato de su `README.md`.

La [prueba de carga en Android](../evidencias/cola-offline.md) confirmó 500 publicaciones
únicas con una cuenta y una zona sintéticas. La tarea 5.1 requiere completar la matriz de
campo en Android y repetirla en iPhone.

1. **500 operaciones** con modo avión, señal débil, cierre forzado, reinicio y batería baja en un
   Android de gama baja y un iPhone: 0 pérdidas y 0 duplicados, con conteos en el servidor
   (`cola-offline.md`).
2. **Sincronización en segundo plano** medida en iOS y Android; la UI no promete inmediatez
   (`segundo-plano.md`).
3. **Conflicto con dos celulares sin conexión:** el segundo ve el motivo y una alternativa, con la
   pantalla del Lote D (`conflicto.md`).
4. **Purga** en línea y sin conexión (`purga.md`).

## Parte 6 · Integración de la Fase 0

Rama: `lote-a/parte-6-integracion` · Tareas 6.1–6.2

1. Integra en `main` las entregas aprobadas de B, C y D y corre el flujo completo: inicio de sesión
   con código → muro sin conexión → tomar favor → aviso → mapa sin conexión. Recorre la lista de
   `docs/fase-0/criterios-de-salida.md`.
2. Compila y depura todo (backend, Android e iOS) con la CI en verde en `main`.

---

## Puntos de contacto con otros lotes

| Con | Qué | Regla |
|---|---|---|
| Lote B | Endpoints del muro, `/v1/auth/*` y el 401 de credenciales tras revocar | El contrato manda; mientras tanto, la sesión de desarrollo y un HTTP falso |
| Lote C | `app/pubspec.yaml`, `infra/` y la baja del token de avisos al cerrar sesión | Cambios pequeños y en PR separado; rebase antes de integrar |
| Lote D | Pantallas que leen `PostRepository`, "acciones por revisar" y `AuthRepository` | D trabaja con los dobles; A solo sobreescribe los proveedores |

## Fuera de alcance

Tablero humanitario y pedidos de ayuda completos (Fase 2), malla entre celulares (I+D) y consola
web (Fase 2).

## Informe de entrega (descripción del PR de cada parte)

```text
Lote A · Parte N · <tema>
Rama: lote-a/parte-N-<tema> · PR: #<número>
Qué cambió: …
Verificación: backend verify ✔ · test:integration ✔ · app analyze ✔ · flutter test ✔ · apk ✔ · dispositivo real ✔
Evidencia: docs/fase-0/evidencias/<archivo>.md (si aplica)
Tareas marcadas: N.1 … N.k
Puntos de contacto tocados: …
Riesgos o pendientes: …
```
