# Lote C · Mapas sin conexión y avisos

| Dato | Valor |
|---|---|
| Dificultad | ★★ Media (el tercero de la Fase 0) |
| Área | `infra/cdn/`, `app/lib/features/mapa/`, `app/lib/features/avisos/` (nuevo), `backend/src/modules/notificaciones/`, `contracts/openapi.yaml` y configuración nativa de `app/android` y `app/ios` |
| Change de OpenSpec | `openspec/changes/archive/2026-11-07-lote-c-mapas-y-avisos/` (proposal, design, specs, tasks) |
| Issue de GitHub | #3 · Lote C · Mapas y avisos |
| Partes | 4. Las Partes 1–2 (mapas) y 3–4 (avisos) pueden avanzar en paralelo |
| Repositorio | https://github.com/stefanods29/Hackathon-ElComercio-Shabat-Shalom (rama `main`) |

> Las tareas con casillas (archivadas al cerrar la Fase 0) viven en `openspec/changes/archive/2026-11-07-lote-c-mapas-y-avisos/tasks.md`; esta guía explica cómo hacerlas.

## Estado del lote

| Parte | Qué entrega | Estado | Responsable | PR |
|---|---|---|---|---|
| 1 | Fuente de teselas | Hecha ([ADR 0008](../../adr/0008-fuente-de-teselas.md) aprobado) | Sebastian Pelaez Lopez | PR de cierre |
| 2 | Mapa sin conexión en la app | Hecha en código; prueba en el celular en el piloto | Sebastian Pelaez Lopez | PR de cierre |
| 3 | Avisos en el backend | Hecha | Sebastian Pelaez Lopez | PR de cierre |
| 4 | Avisos en la app | Hecha en código; conectada a la sesión real por el Lote A; recepción en el celular en el piloto | Sebastian Pelaez Lopez | PR de cierre |

Estados posibles: **Pendiente**, **En curso** o **Hecha** (integrada en `main`). Quien toma una
parte la marca **En curso** con su nombre (en el issue del lote o en un PR pequeño) para que
nadie la duplique, y la marca **Hecha** en el PR que la entrega. Lo que ya está hecho está en
la sección 0.2; lo que falta son las partes pendientes de esta tabla.

Las cuatro partes llegaron en `lote-c/parte-3-avisos-backend` y se integraron en el PR de cierre
de la Fase 0 (`revision/cierre-fase-0`). La CI de ese PR verifica los mapas, el backend y la app.
Ver `infra/cdn/README.md`, `app/lib/features/mapa/README.md` y `app/lib/features/avisos/README.md`.

Al cerrar la Fase 0, el usuario aprobó trasladar al piloto de la Fase 1 (Lote A, parte 5) las
pruebas en un celular:
- Tamaño de la región en gama baja y modo avión (2.1–2.3).
- Recepción de avisos por token y por tópico (4.1–4.4). Necesita la cuenta de servicio de FCM y
  `google-services.json` en el entorno privado.

---

## 0. Antes de empezar (léelo completo)

### 0.1 Reglas obligatorias

1. **Archivos personales fuera del repo.** La configuración local de tu editor u otras herramientas va en
   `.git/info/exclude`, nunca en el repo ni en el `.gitignore`.
2. **Commits con tu identidad de GitHub** (`git config user.name` y `git config user.email`).
3. **Una parte, una rama, un PR.** Al terminar la parte, sube tu rama y abre el PR con la plantilla.
   El Lote A lo revisa e integra (`docs/fase-0/revision-y-entregas.md`).
4. **Código en inglés; contenido en español.** Clases, funciones, archivos y variables en inglés.
   Rutas de la API, campos JSON, códigos de error, tablas, carpetas de funcionalidades
   (`mapa`, `avisos`), textos de la app (`app_es.arb`) y documentación en español.
5. **Primero el contrato** (`contracts/openapi.yaml` + `npx @redocly/cli lint`).
6. **Compilar y depurar al final de cada parte** (sección 0.4).
7. **Sin secretos ni archivos de Firebase en el repo** (es público): `google-services.json`,
   `GoogleService-Info.plist`, `firebase_options.dart` y la cuenta de servicio quedan fuera de
   git y se comparten por un canal privado.
8. **Ningún dato sensible en un aviso:** el texto visible es genérico; el detalle se ve dentro
   de la app.
9. **Respeta el patrón de referencia:** backend como `backend/src/modules/solidaridad/`; app como
   `app/lib/features/solidaridad/` (`domain/` en Dart puro, `data/` con repositorios y proveedores
   de Riverpod, `presentation/` con pantallas sin lógica de negocio).

### 0.2 Lo que ya está hecho (cimientos en `main`)

- **CDN local** (`infra/cdn/`): nginx en `http://localhost:8090` (desde el emulador Android:
  `http://10.0.2.2:8090`) que sirve `infra/cdn/publico/` con soporte de Range y CORS. Ya conoce el
  tipo `application/vnd.pmtiles`.
- **Zonas de demostración** (`backend/scripts/seed-data.ts`): zona piloto entre lng −77,045 y
  −77,025 y lat −12,092 y −12,078 ("Lince (demo)"), y zona vecina entre lng −77,060 y −77,045 y
  lat −12,085 y −12,070.
- **App:** la ruta `Routes.map = '/mapa'` existe y hoy muestra `UnderConstructionScreen`
  (`app/lib/core/router/router.dart`). Proveedores transversales en `app/lib/core/di/providers.dart`
  (`environmentProvider`, `sessionProvider` con `LocalSession.demo` (Beto, zona piloto),
  `secureStoreProvider`, `clockProvider`). Configuración por `--dart-define` en
  `app/lib/core/config/app_environment.dart`. Cliente HTTP: `createApiClient` en
  `core/network/api_client.dart`, con claves de idempotencia de `newLocalId()` en
  `core/network/idempotency.dart`. Textos: `app/lib/l10n/app_es.arb` (claves en inglés).
- **Backend:** el módulo `notificaciones` es un esqueleto (`NotificationsModule`). Para la API
  tienes errores de dominio, `@Idempotent()`, `@CurrentActor()`, el puerto `JobQueue` con
  `InMemoryJobQueue` (`drain()`) y, cuando el Lote B entregue su Parte 4, pg-boss,
  `JobHandlerRegistry` y el contrato `SEND_NOTIFICATION_JOB`.
- Pruebas del backend: unitarias `*.spec.ts`; integración en `test/integration/` con
  `createTestApp(inject('databaseUrl'), overrides)` y los vecinos sembrados (`ana`, `beto`,
  `carla`, `dario`, `elena`).

### 0.3 Preparar el entorno

```bash
git clone https://github.com/stefanods29/Hackathon-ElComercio-Shabat-Shalom.git
cd Hackathon-ElComercio-Shabat-Shalom
git config user.name "<tu nombre>"
git config user.email "<tu correo de GitHub>"
cd infra && docker compose up -d
cd ../backend && npm ci && npm run dev:keys && npm run db:migrate && npm run db:seed && npm run start:dev
cd ../app && flutter pub get && flutter gen-l10n
```

Necesitas Flutter 3.47.9, Android Studio (SDK 36, Build-Tools 36, NDK 28.2.13676358), un Android
real de gama baja y, para iOS, una Mac con Xcode o los builds de CI y TestFlight. Además:
Docker, Node 26 y la CLI `pmtiles` (https://github.com/protomaps/go-pmtiles/releases).

### 0.4 Ciclo de cada parte

1. `git switch main && git pull` y luego `git switch -c lote-c/parte-<n>-<tema>`.
2. Contrato primero (si la parte toca la API).
3. Implementa con pruebas.
4. **Compila y depura:**
   - backend: `npm run verify` y
     `DATABASE_URL_ADMIN=postgres://vecinal:vecinal@localhost:5432/vecinal npm run test:integration`;
   - app: `dart format lib test`, luego `tool\verify.cmd` (Windows) o `tool/verify.sh`, y
     `flutter build apk --debug`;
   - specs y contrato: `openspec validate --all --strict` y `npx @redocly/cli lint contracts/openapi.yaml`.
5. Marca las tareas en `tasks.md`, sube la rama y abre el PR con el informe (sección 7).

---

## Parte 1 · Fuente de teselas

Rama: `lote-c/parte-1-teselas` · Tareas 1.1–1.4 · Spec: `specs/mapas/region-offline/spec.md`

1. **ADR** `docs/adr/0008-fuente-de-teselas.md` (Contexto, Opciones, Decisión, Consecuencias):
   - Prohibido: los servidores de teselas de OpenStreetMap
     (`tile.openstreetmap.org` no permite la descarga offline masiva).
   - Opción A (recomendada por la arquitectura): **PMTiles propio** generado con datos de OSM
     (licencia ODbL, atribución obligatoria), servido desde la CDN (R2 en producción).
   - Opción B: un proveedor cuyos términos permitan expresamente la descarga offline. Cita la
     cláusula exacta y su fecha.
   - Registra la decisión del equipo y agrega el ADR al índice `docs/adr/README.md`.
2. **Script reproducible** `infra/cdn/scripts/build-district-tiles.sh` (y su equivalente
   `.ps1` para Windows) que genera `infra/cdn/publico/distrito.pmtiles`:
   - Camino rápido: `pmtiles extract <url de un build diario de Protomaps> distrito.pmtiles
     --bbox=-77.07,-12.10,-77.01,-12.06 --maxzoom=15`. Antes revisa y anota en el ADR los términos
     de los builds de Protomaps.
   - Camino propio: el extracto de Perú de Geofabrik + Planetiler (en Docker) con los mismos
     límites y `maxzoom` 15.
   - **El `.pmtiles` no se sube a git**: agrega `infra/cdn/publico/*.pmtiles` al `.gitignore`.
     El script imprime el tamaño final.
3. **Estilo propio** en `infra/cdn/publico/estilos/vecinal.json`, generado con
   `@protomaps/basemaps` (5.x) mediante `infra/cdn/scripts/build-style.mjs`: sabor claro,
   etiquetas en español, `glyphs` y `sprite` servidos por la misma CDN (copia las fuentes y los
   sprites de los assets de Protomaps a `infra/cdn/publico/fuentes/` y `infra/cdn/publico/sprites/`,
   revisando su licencia), y `attribution: "© OpenStreetMap contributors"` en la fuente.
4. **Verifica:**
   - `curl -s -o /dev/null -w "%{http_code}" -r 0-1023 http://localhost:8090/distrito.pmtiles` → `206`;
   - un visor mínimo `infra/cdn/publico/visor.html` (maplibre-gl + pmtiles desde un CDN de npm)
     carga el estilo y muestra el distrito.
5. **Importante para la Parte 2:** comprueba si `maplibre_gl` (MapLibre Native) acepta fuentes
   `pmtiles://` **y además** puede descargarlas como región offline. Si no, sirve las mismas
   teselas como XYZ (`/teselas/{z}/{x}/{y}.mvt`, por ejemplo con `pmtiles serve` o un contenedor
   `martin` agregado a `docker-compose.yml`) y anota el resultado en el ADR.

---

## Parte 2 · Mapa sin conexión en la app

Rama: `lote-c/parte-2-mapa-offline` · Tareas 2.1–2.4

1. `flutter pub add maplibre_gl`. Revisa el `minSdk` de Android y la versión mínima de iOS que
   pide el paquete y ajústalos en `android/app/build.gradle.kts` y en `ios/Podfile`.
2. **Configuración:** en `AppEnvironment` agrega `mapStyleUrl`
   (`--dart-define=MAP_STYLE_URL`, por defecto `http://10.0.2.2:8090/estilos/vecinal.json`) y los
   límites del distrito piloto. En Fase 0 son una constante por zona, porque el stream `mi_zona`
   no envía el polígono. Para HTTP local en Android agrega `android:usesCleartextTraffic="true"`
   **solo** en `android/app/src/debug/AndroidManifest.xml`, nunca en `main`.
3. **`lib/features/mapa/`:**
   - `domain/offline_region.dart`: `OfflineRegion { id, name, bounds, minZoom (10), maxZoom (15),
     status, downloadedBytes }` y `OfflineRegionStatus { notDownloaded, downloading, ready, failed }`.
   - `domain/map_region_repository.dart`: el puerto `MapRegionRepository` con
     `watchRegions()`, `download(region)` (que emite el progreso), `cancel(id)` y `delete(id)`.
   - `domain/download_policy.dart`: `bool canDownload({required bool onWifi, required bool
     allowMobileData})`. Solo Wi-Fi por defecto.
   - `data/maplibre_region_repository.dart`: la implementación con la API offline de
     `maplibre_gl` (`downloadOfflineRegion`, `getListOfRegions`, `deleteOfflineRegion`;
     confirma los nombres en el README de la versión instalada). El tamaño en MB se mide con el
     avance de la descarga o con el tamaño del directorio de la base offline, y se muestra en MB.
   - `data/providers.dart`: `mapRegionRepositoryProvider`, `offlineRegionsProvider` y la
     conectividad con `connectivity_plus`, que ya es una dependencia.
   - `presentation/map_page.dart`: `MapPage` con el mapa centrado en la zona, el botón grande
     "Descargar mapa de mi distrito", el avance en % y MB, cancelar y borrar, el interruptor
     "Permitir con datos móviles" y la atribución **"© OpenStreetMap contributors" siempre
     visible y legible al 200 %**. Envuelve el widget del mapa en un `MapView` reemplazable para
     poder probar la pantalla sin un motor nativo.
4. **Router:** en `core/router/router.dart`, cambia `UnderConstructionScreen` de `/mapa` por
   `MapPage`.
5. **Textos** en `app_es.arb` con claves en inglés: `mapTitle`, `downloadDistrictMap`,
   `downloadOnlyOnWifi`, `allowMobileData`, `downloadProgress` (con marcadores `percent` y
   `megabytes`), `cancelDownload`, `deleteDownloadedMap`, `mapReadyOffline` y `mapAttribution`.
6. **Pruebas:** unitarias de `canDownload`; de widgets de `MapPage` con un repositorio falso
   (avance, cancelar, borrar, atribución visible con `textScaler` 2,0 y objetivos de 48 dp con
   `meetsGuideline(androidTapTargetGuideline)`).
7. **Evidencia** en `docs/fase-0/evidencias/mapas.md`: modelo y versión del Android de gama baja,
   tamaño de la región, tiempo de descarga por Wi-Fi, prueba en **modo avión** dentro del distrito
   (capturas) y la verificación en iOS.

---

## Parte 3 · Avisos en el backend

Rama: `lote-c/parte-3-avisos-backend` · Tareas 3.1–3.5 · Spec: `specs/notificaciones/avisos-push/spec.md`

1. **Contrato:**
   - `POST /v1/dispositivos` (con token, `@Idempotent()`): cuerpo
     `{ token: string (1–4096), plataforma: 'android' | 'ios' }` → 200 `Dispositivo { id,
     plataforma, registradoEn }`.
   - `POST /v1/dispositivos/baja` (con token): cuerpo `{ token }` → 204. Se usa al cerrar sesión.
     Es un POST para no poner el token en la URL ni en los logs.
2. **Migración** `backend/src/modules/notificaciones/infrastructure/migrations/202611070300_notificaciones_dispositivos.ts`:
   ```sql
   CREATE SCHEMA IF NOT EXISTS notificaciones;
   CREATE TABLE notificaciones.dispositivos (
     id               uuid        PRIMARY KEY DEFAULT uuidv7(),
     usuario_id       uuid        NOT NULL REFERENCES identidad.usuarios(id),
     token            text        NOT NULL UNIQUE CHECK (char_length(token) BETWEEN 1 AND 4096),
     plataforma       text        NOT NULL CHECK (plataforma IN ('android', 'ios')),
     creado_en        timestamptz NOT NULL DEFAULT now(),
     actualizado_en   timestamptz NOT NULL DEFAULT now(),
     dado_de_baja_en  timestamptz
   );
   CREATE INDEX dispositivos_usuario_idx ON notificaciones.dispositivos (usuario_id)
     WHERE dado_de_baja_en IS NULL;
   CREATE TABLE notificaciones.avisos_enviados (
     aviso_id    uuid        PRIMARY KEY,
     plantilla   text        NOT NULL,
     estado      text        NOT NULL CHECK (estado IN ('enviando', 'enviado')),
     creado_en   timestamptz NOT NULL DEFAULT now()
   );
   ```
   Nada de esto va a la publicación `powersync`.
3. **Puerto y adaptadores** (`application/ports.ts` e `infrastructure/`):
   ```ts
   export interface PushMessage {
     readonly title: string;      // generic, never sensitive
     readonly body: string;       // e.g. "Tienes una actualización"
     readonly data: Readonly<Record<string, string>>; // ids and type only
   }
   export interface NotificationPort {
     sendToToken(token: string, message: PushMessage): Promise<'sent' | 'invalid_token'>;
     sendToTopic(topic: string, message: PushMessage): Promise<void>;
   }
   export const NOTIFICATION_PORT = Symbol('NOTIFICATION_PORT');
   ```
   - `FcmNotificationAdapter` con `firebase-admin` (14.x): `initializeApp` con la cuenta de
     servicio leída de `FIREBASE_SERVICE_ACCOUNT_BASE64`, y `getMessaging().send({ token |
     topic, notification: { title, body }, data, android: { priority: 'high' } })`. El error
     `messaging/registration-token-not-registered` devuelve `'invalid_token'`.
   - `FakeNotificationAdapter`: guarda lo enviado para las pruebas.
   - Configuración `NOTIFICATION_DRIVER = 'fake' | 'fcm'` (por defecto `fake`; prohibido `fake` en
     producción), documentada en `.env.example` sin valores reales.
4. **Casos de uso:** `RegisterDevice` (upsert por token; si el token era de otro usuario, se
   reasigna y se reactiva) y `UnregisterDevice` (marca `dado_de_baja_en`).
5. **Manejadores de trabajos.** Usan `JobHandlerRegistry` y `SEND_NOTIFICATION_JOB` de la Parte 4
   del Lote B. Si aún no está en `main`, desarrolla y prueba con `InMemoryJobQueue` y `drain()`:
   - `solidaridad.favor_tomado` → arma un `SendNotificationJob` con
     `avisoId = uuidv5(eventoId + ':' + autorId)` (paquete `uuid`),
     `destino = { tipo: 'usuario', usuarioId: carga.autorId }`, `plantilla = 'favor_tomado'` y
     `datos = { publicacionId: agregadoId }`, y lo encola con `singletonKey = avisoId`.
   - `notificaciones.enviar_aviso` → **idempotente**:
     1. Reclama el envío con `INSERT INTO notificaciones.avisos_enviados (aviso_id, plantilla,
        estado) VALUES (…, 'enviando') ON CONFLICT DO NOTHING`. Si no insertó, ya se envió o se
        está enviando: termina sin hacer nada.
     2. Envía a cada dispositivo activo del usuario, o al tópico `zona-<zonaId>`.
     3. Marca `estado = 'enviado'`. Si el envío falla, borra el reclamo y relanza el error para
        que pg-boss reintente.
     4. Si un token es inválido, da de baja ese dispositivo.
   - Plantillas (`domain/templates.ts`): `favor_tomado` → título "Vecinal", cuerpo "Tienes una
     actualización" y `data { tipo: 'favor_tomado', publicacionId }`. `aviso_de_zona` → título y
     cuerpo públicos que escribe el coordinador.
6. **Aviso por tópico para la evidencia:** `POST /v1/operacion/avisos/zona` con
   `@RequireRole('coordinador')` y `@RequireTrustLevel(3)` (decoradores de la Parte 3 del Lote B),
   cuerpo `{ zonaId, titulo, texto }`, que encola un `aviso_de_zona`. Solo información pública.
7. **Pruebas:** unitarias de las plantillas (afirma que el cuerpo es genérico y que `data` solo
   lleva ids); integración del registro idempotente, la baja, el trabajo entregado dos veces (el
   doble cuenta **1** envío) y el token inválido (el dispositivo queda dado de baja).

---

## Parte 4 · Avisos en la app

Rama: `lote-c/parte-4-avisos-app` · Tareas 4.1–4.5

1. **Firebase:** el equipo crea el proyecto. `flutter pub add firebase_core firebase_messaging` y
   `flutterfire configure` en tu máquina. **No subas** `lib/firebase_options.dart`,
   `android/app/google-services.json` ni `ios/Runner/GoogleService-Info.plist`: agrégalos al
   `.gitignore` de `app/` y documenta en `app/README.md` cómo obtenerlos.
2. **La app debe compilar sin Firebase** (en CI y para los demás lotes):
   - inicializa Firebase solo si `--dart-define=ENABLE_PUSH=true`;
   - en `android/app/build.gradle.kts`, aplica el plugin `com.google.gms.google-services` solo si
     existe `google-services.json`.
3. **`lib/features/avisos/`:**
   - `domain/push_registration.dart`: el puerto `PushRegistration` con `register(token,
     platform)` y `unregister(token)`.
   - `data/api_push_registration.dart`: llama a `POST /v1/dispositivos` y
     `POST /v1/dispositivos/baja` con `Idempotency-Key = newLocalId()`. Si falla por falta de
     red, guarda el token pendiente y reintenta al volver la conexión.
   - `data/push_service.dart`: pide el permiso (iOS y Android 13+), obtiene el token y lo registra,
     escucha `onTokenRefresh`, se suscribe al tópico `zona-<zoneId>` y se desuscribe al cambiar de
     zona o cerrar sesión. Maneja `getInitialMessage()` y `onMessageOpenedApp`. El manejador de
     segundo plano va en una función de primer nivel con `@pragma('vm:entry-point')` y no procesa
     datos sensibles.
   - `domain/notification_route.dart`: la función pura `String? routeFor(Map<String, String> data)`.
     Para `favor_tomado` devuelve `/publicaciones/<publicacionId>`.
4. **Abrir la pantalla correcta:** agrega `Routes.postDetail = '/publicaciones/:id'` con una
   pantalla de detalle mínima en `features/solidaridad/presentation/`. Coordínalo con el Lote D,
   que la pule. Si no hay sesión, guarda el destino y llévalo ahí después de iniciar sesión.
5. **Pruebas:** unitarias de `routeFor` y del registro con una API falsa (token nuevo, refresco,
   baja); de widgets del permiso denegado, que muestra cómo activarlo sin bloquear la app.
6. **Evidencia** en `docs/fase-0/evidencias/avisos.md`: aviso por token (favor tomado) y por
   tópico (aviso de zona) recibidos en Android y en iPhone (APNs configurado en Firebase), una
   captura de la pantalla bloqueada que muestre el texto genérico y la prueba del trabajo
   duplicado con un solo aviso.

---

## 6. Puntos de contacto con otros lotes

| Con | Qué | Regla |
|---|---|---|
| Lote B | `SEND_NOTIFICATION_JOB`, `JobHandlerRegistry`, `@RequireRole` y `@RequireTrustLevel` | B los define; mientras tanto usa `InMemoryJobQueue` y deja la ruta operativa para cuando B3 esté en `main` |
| Lote D | `/mapa` y el detalle `/publicaciones/:id` | C entrega las pantallas; D revisa la accesibilidad y el diseño |
| Lote A | `app/pubspec.yaml`, `android/`, `ios/` y cierre de sesión (baja del token) | Paquetes en un commit pequeño y temprano; el cierre de sesión del Lote A llama a `unregister` |
| Todos | `contracts/openapi.yaml`, `app_es.arb`, `core/router/router.dart` | Cambios pequeños; rebase antes de entregar |

## Fuera de alcance

SMS de respaldo para coordinadores (Fase 2), mapas de calor de pedidos de ayuda (Fase 2), malla
entre celulares (I+D) y mapas de otros distritos (Fase 3).

## 7. Informe de entrega (descripción del PR de cada parte)

```text
Lote C · Parte N · <tema>
Rama: lote-c/parte-N-<tema> · PR: #<número>
Qué cambió: …
Contrato / migraciones / variables nuevas: …
Verificación: backend verify ✔ · test:integration ✔ · app verify ✔ · apk ✔ · openspec ✔ · redocly ✔
Evidencia: docs/fase-0/evidencias/<archivo>.md
Tareas marcadas: N.1 … N.k
Puntos de contacto tocados: …
Riesgos o pendientes: …
```

## 8. Definición de terminado del lote

Las 4 partes aprobadas e integradas, el ADR de teselas aprobado, el mapa navegable en modo avión
en un Android de gama baja, avisos por token y por tópico con evidencia en Android e iPhone, y el
change listo para archivarse.
