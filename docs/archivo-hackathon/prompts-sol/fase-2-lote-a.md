# Encargo · Fase 2, Lote A · Pedidos offline y modo operativo

Eres el ingeniero del **Lote A de la Fase 2** del proyecto "App vecinal" (Hackathon El Comercio):
backend NestJS 12 + PostgreSQL/PostGIS, app Flutter 3.47 y contrato OpenAPI en un monorepo. El
Lote A es el más importante de la fase: integra a B, C y D y maneja los datos más sensibles
(pedidos de ayuda y ubicación exacta). Un supervisor revisa cada parte, corre las pruebas en su
máquina e integra.

**Tu trabajo es escribir el código y sus pruebas, no ejecutarlos.** Si en tu entorno sí puedes
correr algo, córrelo y pega la salida en el informe; si no, dilo. Nunca escribas "pasa" sin haberlo
visto pasar.

**Alcance:** las partes 1 a 4, **una por una**. Al terminar cada parte te detienes, entregas el
informe de la sección 9 y esperas el visto bueno. Las partes 5 (penetración y campo) y 6
(integración y simulacro) necesitan celulares, aliados y al equipo: no las marques ni las simules.

---

## 1. Estado actual y punto de partida

- La Fase 1 completa ya está en `main` (commit `cace84e` o posterior): directorio, reseñas,
  moderación, fotos, telemetría de sincronización, directorio de emergencia offline, cambio de zona,
  borrado de cuenta y pantallas del piloto.
- Las ramas viejas se archivaron como etiquetas `archivo/*`. No las uses como base.
- Tu rama `f2-lote-a/parte-1-pedidos-offline` solo tiene el plan de OpenSpec y **parte de un `main`
  anterior a la Fase 1**. Antes de escribir código, tráele el `main` actual (autorizado solo para
  esto):

```bash
git fetch origin
git switch f2-lote-a/parte-1-pedidos-offline
git merge origin/main -m "Trae la Fase 1 integrada a la rama del Lote A de la Fase 2"
git push origin f2-lote-a/parte-1-pedidos-offline
```

- El Lote B de la Fase 2 está en `origin/f2-lote-b/modulo-emergencias` (todavía no en `main`). Su
  contrato es tu fuente de verdad (sección 4). Para leerlo sin mezclarlo en tu rama:
  `git show origin/f2-lote-b/modulo-emergencias:<ruta>`.
- Las ramas de las partes siguientes salen de la anterior aprobada:
  `f2-lote-a/parte-2-streams-por-asignacion`, `parte-3-modo-operativo`, `parte-4-tablero-offline`.

## 2. Reglas que no se negocian

1. Lee `AGENTS.md`, `CONTRIBUTING.md`, `docs/fase-2/README.md` (reglas para todos los lotes),
   `docs/fase-2/lote-a-pedidos-offline-y-modo-operativo/README.md` y tu change
   `openspec/changes/fase-2-lote-a-pedidos-offline-y-modo-operativo/`.
2. **Datos sensibles nunca en streams automáticos.** Descripción, ubicación exacta, salud y riesgo
   vital solo viajan en streams `auto_subscribe: false`, al celular autorizado y mientras dure la
   autorización.
3. **Minimización:** al aceptar un caso llega solo la ubicación aproximada; la exacta, solo en
   estado `en_camino`, en un stream aparte.
4. **Todo acceso a un dato sensible queda auditado** en el backend (tabla `emergencias.auditoria`
   del Lote B).
5. Ningún aviso ni log lleva datos sensibles. La app siempre muestra el estado real y las
   alternativas oficiales (116, 105 y 106).
6. Código en inglés; API, base de datos y textos en español. Textos de la UI solo en
   `app/lib/l10n/app_es.arb`.
7. **Git:** commits en español en imperativo ("Agrega…", "Corrige…"), sin prefijos tipo `feat:`.
   **Ninguna mención de herramientas de IA** en commits, archivos ni comentarios, ni líneas
   `Co-Authored-By`. Subes solo tu rama: nada de merge a `main`, PR, rebase de ramas ajenas ni
   force-push.
8. No marques una tarea `[x]` sin la evidencia que pide. Escribe "pendiente de verificar".
9. Nunca subas contraseñas, claves, tokens, `.env` reales ni datos reales de vecinos.

10. **Responsable del lote:** JDiazD33 (lo asumió en lugar de Stefano). En tu primer commit de la
    parte 1, cambia "Stefano" por "JDiazD33" en la tabla de estado de
    `docs/fase-2/lote-a-pedidos-offline-y-modo-operativo/README.md`. En cualquier campo de
    responsable, autor o revisor (tablas de estado, evidencias, ADRs, commits) va **solo** el
    usuario de GitHub de un colaborador del equipo, como `JDiazD33` o `stefanods29`. Nunca el nombre
    de un agente, de un modelo ni de una herramienta.
11. **Archivos compartidos** (`contracts/openapi.yaml`, `infra/powersync/sync-config.yaml`,
    `app/lib/l10n/app_es.arb`, `app/lib/core/router/router.dart`, `app/lib/core/router/routes.dart`,
    `app/pubspec.yaml`, `app/lib/core/sync/local_schema.dart` y `backend/src/shared/shared.module.ts`):
    - Solo **agregas al final** de la sección que corresponde. No reordenas, no renombras y no
      reformateas lo que escribieron otros.
    - Una clave de texto, una ruta o un stream nuevo llevan el prefijo de tu tema (por ejemplo
      `helpRequest…`, `/emergencia/pedido`, `mi_pedido`) para no chocar con B, C o D.
    - Si necesitas cambiar algo que ya existe, no lo cambies: anótalo en el informe y lo resuelve el
      integrador.
    - Nunca edites `pubspec.lock` ni `package-lock.json` a mano. Si agregas un paquete, avísalo en
      el informe y el integrador regenera el lockfile.

## 3. Código existente sobre el que construyes (no lo dupliques)

| Qué | Dónde | Cómo se usa |
|---|---|---|
| Cola de subida con idempotencia | `app/lib/core/sync/command_queue.dart` (`enqueueCommand`) | Comando y envío en **una** transacción; `optimistic` para la fila local |
| Tipos de comando y rutas | `app/lib/core/submissions/submission.dart` (`SubmissionKind`) y `app/lib/core/sync/command_routes.dart` | **Agrega al final** (`requestHelp`, `changeRequestState`…). Los nombres se guardan en la base: nunca renombres ni reordenes |
| Conector de subida | `app/lib/core/sync/vecinal_connector.dart` | Clasifica 2xx, 4xx definitivo y reintentos; no lo reescribas |
| Esquema local | `app/lib/core/sync/local_schema.dart` | Tablas sincronizadas y `envios` *local-only* |
| Caché cifrada del caso asignado | `app/lib/features/emergencias/assigned_case_cache.dart` | Base cifrada aparte, purga al vencer, al reasignar y al cerrar sesión. **Extiéndela** para las partes 2 y 3 |
| Purga de cuenta | `app/lib/core/storage/account_data_purge.dart` y `AuthenticatedSyncSession.discard` | Todo lo nuevo que guardes por cuenta se borra aquí |
| Pantallas de emergencia del piloto | `app/lib/features/emergencias/emergency_page.dart` (Lote D, Fase 1) | El Lote D de la Fase 2 (`origin/f2-lote-d/tablero-de-emergencia`) arma "Necesito ayuda"; tú le das puertos y repositorios |
| Directorio de emergencia offline | `app/lib/features/emergencias/data/` y `public_emergency_directory.dart` | Alternativas oficiales siempre disponibles sin señal |
| Sync Streams | `infra/powersync/sync-config.yaml` | Mismo estilo que `caso_asignado` y los streams de la Fase 1 |
| Pruebas de acceso de streams | `backend/test/sync/datos-publicos.spec.ts` | **Copia este patrón** (`parseSyncConfig`, `evaluateRow`, `getBucketParameterQuerier`) para cada stream nuevo |
| Telemetría de la cola | `app/lib/core/sync/sync_telemetry_reporter.dart` | Los pedidos cuentan como un envío más; no agregues campos con datos del pedido |

## 4. Contrato del Lote B de la Fase 2 (léelo en su rama)

Tablas (`backend/src/modules/emergencias/infrastructure/migrations/202611090200_emergencias_operacion.ts`):

- `emergencias.pedidos_ayuda`: `id`, `evento_id`, `zona_id`, `autor_id`, `necesidad`
  (`agua|alimentos|medicamentos|traslado|albergue|otro`), `prioridad` (`alta|media|baja`), `estado`
  (`enviado|visto|en_camino|atendido|derivado|cerrado_sin_atender`), `version`, `celda`, `visto_en`,
  `cerrado_en`, `vence_en`, `anonimizado_en`. El campo `detalle` ahora es un texto genérico.
- `emergencias.detalles_pedidos`: `pedido_id`, `descripcion`, `lat`, `lng`. **Privada**: solo en
  el stream de ubicación exacta.
- `emergencias.asignaciones`: `pedido_id`, `usuario_id`, `rol` (`coordinador|brigadista`),
  `acceso_hasta`, `finalizada_en`.
- `emergencias.historial_pedidos`: `pedido_id`, `desde`, `hasta`, `usuario_id`, `rol`,
  `ocurrido_en`, `motivo`.
- `emergencias.recursos_criticos`: `tipo`, `cantidad`, `celda`, `reportado_en`,
  `umbral_segundos`, `verificacion`, `etiqueta_publica`, `fuente_url`, `oficial`. **Privados:**
  `reportante_id` y `huella`.

Rutas (`backend/src/modules/emergencias/api/*.controller.ts` y `schemas.ts`):

- `POST /v1/pedidos-ayuda`: cuerpo estricto `{ id, eventoId, necesidad, prioridad, descripcion,
  ubicacion: { lat, lng }, riesgoVital }`.
- `GET /v1/pedidos-ayuda/{id}` y `POST /v1/pedidos-ayuda/{id}/estado`:
  `{ versionVista, estado, motivo? }`.
- `POST /v1/pedidos-ayuda/{id}/asignaciones`: `{ versionVista, usuarioId, rol }`.
- `GET /v1/zonas/{zonaId}/recursos` y `GET /v1/zonas/{zonaId}/celdas`.

Si necesitas algo que B no tiene (por ejemplo una ubicación aproximada distinta de `celda`, o una
tabla de agregados por celda con mínimo de 3), **no lo inventes en el backend de B**. Anótalo en el
informe como "pedido a B" con el nombre de columna propuesto, y mientras tanto usa un doble.

## 5. Parte 1 · Pedidos de ayuda sin conexión (tareas 1.1–1.6)

- `SubmissionKind.requestHelp` → `POST /v1/pedidos-ayuda` con el cuerpo de B. El `id` es UUIDv7
  generado en el celular, el mismo que el del recurso. La `Idempotency-Key` es la del comando.
- **La descripción y la ubicación exacta no van en una tabla sincronizada.** Guárdalas en la caché
  cifrada por cuenta (como `AssignedCaseCache`) hasta el acuse, y bórralas del celular cuando el
  pedido se cierre o venza. El cuerpo del comando en `comandos` es lo único que sube.
- Mientras no hay acuse, la UI dice textualmente "Tu pedido **todavía no fue enviado**. Nadie lo ha
  recibido." y ofrece 116, 105 y 106.
- Stream `mi_pedido` con **`auto_subscribe: false`**, suscrito solo mientras el vecino tiene un
  pedido abierto. Filtro `autor_id = auth.user_id()`, con columnas `id, estado, necesidad,
  prioridad, version, creado_en, cerrado_en` más el historial sin `usuario_id`. Nada de
  `detalles_pedidos`.
- Reconciliación: si al reconectar llega una versión más nueva cerrada o derivada, se muestra con
  su motivo y no se reintenta el comando (4xx definitivo → "No se pudo completar").
- Pruebas que escribes:
  - una matriz de 500 pedidos con interrupciones (0 pérdidas y 0 duplicados), sobre el estilo de
    `vecinal_connector_test.dart`;
  - HTTP falso para 201/409/422;
  - acceso del stream: otra cuenta 0 filas; ninguna columna de `detalles_pedidos`;
  - purga al cerrar sesión.

## 6. Parte 2 · Streams bajo demanda por asignación (2.1–2.4)

- Extiende `caso_asignado` (ya existe) con `necesidad, prioridad, estado, version, celda`, solo con
  asignación activa (`finalizada_en IS NULL`) del `auth.user_id()`.
- Stream aparte `caso_ubicacion_exacta` (`auto_subscribe: false`) desde
  `emergencias.detalles_pedidos`, solo si el pedido está en `en_camino` y la asignación sigue
  activa.
- PowerSync no evalúa `now()` en cada consulta: el vencimiento por `acceso_hasta` lo hace el
  barrido de B poniendo `finalizada_en`. La app además purga por su cuenta al vencer.
- Auditoría: la app pide la apertura a B (ruta auditada) antes de suscribirse. Pruebas de acceso:
  sin asignación 0 filas; exacta 0 filas antes de `en_camino`; al reasignar, el anterior 0 filas.

## 7. Parte 3 · Modo operativo protegido (3.1–3.4)

- `app/lib/core/security/`: puerto `OperationalLock` (PIN o biometría con `local_auth`) y cierre
  por inactividad con reloj inyectable (`clockProvider`). Si agregas `local_auth`, Android exige que
  `MainActivity.kt` extienda `FlutterFragmentActivity`: cámbialo en
  `app/android/app/src/main/kotlin/pe/shabatshalom/vecinal/MainActivity.kt` y explícalo en el
  informe.
- `FLAG_SECURE` en Android con un `MethodChannel` propio y una vista difuminada en iOS
  (`AppDelegate`) solo en las pantallas sensibles. Sin paquetes sin mantenimiento.
- Caducidad local (por ejemplo, 24 horas o al cerrar el caso) aunque no haya señal, sobre la purga
  existente. Pruebas con reloj falso; la verificación en celulares queda para la parte 5.

## 8. Parte 4 · Tablero sin conexión (4.1–4.4)

- Stream público de agregados por celda solo desde una tabla o vista de B que ya excluya las celdas
  con menos de 3 pedidos. Si no existe, pídesela a B (sección 4).
- Recursos críticos públicos sin `reportante_id` ni `huella`, con "reportado hace X" y la marca de
  desactualizado por `umbral_segundos`.
- En modo emergencia: prioridad 1 para los streams críticos y fotos apagadas (la cola de fotos del
  Lote C está en `app/lib/features/media/`).

## 9. Errores que rompieron la integración de la Fase 1 (no los repitas)

- Un `superRefine` o `pipe` de Zod mal tipado (`z.string().pipe(z.coerce.number())`): usa
  `z.coerce.number()` directo en los query params.
- Usar `this.logger` sin declararlo, o variables con nombres que no existen (`zonaId` en lugar de
  `zoneId`).
- `LayoutBuilder` dentro de un widget que va en un `AlertDialog`: el diálogo pide tamaños
  intrínsecos y la prueba falla.
- En pruebas de widgets, `ensureVisible` sobre un elemento de un `ListView` que aún no se
  construyó: usa `scrollUntilVisible(..., scrollable: find.byType(Scrollable).first)`.
- YAML del contrato con comas dentro de un `description` sin comillas.
- Una prueba de migraciones que revierte una tabla de la que dependen migraciones posteriores:
  revierte primero las dependientes.
- `ST_Project(..., ${param}, ...)` sin cast (`::float8`).
- Un reintento idempotente responde **200** con el cuerpo guardado, no el código original.
- Pruebas que cuentan filas globales (zonas, servicios) cuando otras suites escriben en la misma
  base: filtra por tus propios datos.
- Agregar al puerto un método que otro lote ya agregó con otro nombre: busca antes con
  `grep -rn` en `app/lib` y `backend/src`.
- Imports no ordenados, `if` sin llaves y `const` faltantes: `flutter analyze` falla con avisos.

## 10. Comandos que el supervisor va a correr

```bash
cd backend && npm run verify && npm run test:integration
cd app && tool/verify.sh
cd infra/cdn && npm test
npx @redocly/cli lint contracts/openapi.yaml
openspec validate --all --strict
```

## 11. Informe al terminar cada parte

1. Rama, base (commit del que salió), SHA final y `git log --oneline` de la parte.
2. `git diff --stat` contra la base.
3. Tareas hechas, con los archivos de cada una. Las que no se pudieron verificar quedan como
   "pendiente de verificar".
4. Cambios de contrato (`openapi.yaml`, `sync-config.yaml`, esquema local), migraciones y variables
   de entorno nuevas.
5. Pedidos a B, C o D, con la columna o ruta propuesta.
6. Desvíos del plan y por qué.
7. Resultado de `git log --format=%B <base>..HEAD | grep -iE "co-authored|claude|chatgpt|openai|anthropic"`,
   que debe salir vacío.
8. Confirmación de que solo subiste tu rama, sin merge, PR ni force-push.
