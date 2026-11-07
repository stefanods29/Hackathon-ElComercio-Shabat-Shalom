# Lote D · Experiencia accesible

| Dato | Valor |
|---|---|
| Dificultad | ★ Media-baja (el más accesible de los cuatro) |
| Área | Solo la app: `app/lib/core/theme/`, `app/lib/core/ui/`, `app/lib/features/publicar/`, `app/lib/features/onboarding/`, `app/lib/features/cuenta/` (nuevo), `app/lib/features/solidaridad/presentation/`, `app/lib/l10n/`, `app/test/` |
| Change de OpenSpec | `openspec/changes/lote-d-experiencia-accesible/` (proposal, design, specs, tasks) |
| Issue de GitHub | #4 · Lote D · Experiencia accesible |
| Partes | 5, en orden |
| Repositorio | https://github.com/stefanods29/Hackathon-ElComercio-Shabat-Shalom (rama `main`) |

> Las tareas con casillas viven en `openspec/changes/lote-d-experiencia-accesible/tasks.md`; esta guía explica cómo hacerlas.

## Estado del lote

| Parte | Qué entrega | Estado | Responsable | PR |
|---|---|---|---|---|
| 1 | Sistema de diseño accesible | Hecha | — | — |
| 2 | Publicar en 3 toques | Hecha | — | — |
| 3 | Estados visibles y "acciones por revisar" | Hecha | — | — |
| 4 | Tutorial y modo práctica | Hecha | — | — |
| 5 | Inicio de sesión, zona y cuenta | Hecha | — | — |

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
4. **Código en inglés; textos en español.** Clases, widgets, funciones, archivos y claves del ARB
   en inglés; todo lo que ve el vecino en español, en `app/lib/l10n/app_es.arb` y nunca escrito
   directo en un widget.
5. **Las pantallas solo conocen interfaces y proveedores.** Nunca importes PowerSync, Dio ni
   clases de `data/` desde `presentation/`; usa los puertos de `domain/` y los proveedores de
   Riverpod. Así el Lote A cambia la implementación sin tocar tus pantallas.
6. **No cambies interfaces compartidas** (`PostRepository`, `SyncService`, `Submission`) sin
   acordarlo con el Lote A. Si necesitas algo nuevo, propónlo en el informe.
7. **Compilar y depurar al final de cada parte** (sección 0.4).
8. **Meta WCAG 2.2 AA:** contraste de 4,5:1 (texto) y 3:1 (texto grande e íconos), objetivos
   táctiles de 48 dp o más, texto al 200 % sin cortes, etiquetas semánticas en español y el color
   nunca como única señal.

### 0.2 Lo que ya está hecho (cimientos en `main`)

| Pieza | Archivo | Qué hace |
|---|---|---|
| Tema accesible | `core/theme/accessible_theme.dart` | `AccessibleTheme.light()` y `dark()`: semilla `#0B5FAD`, `contrastLevel: 0.5`, botones de 48 dp con texto de 18 |
| Chip de estado | `core/ui/submission_status_chip.dart` | `SubmissionStatusChip(status:)`: ícono + texto para *Guardado en tu celular*, *Enviado* y *No se pudo completar* |
| Aviso sin conexión | `core/ui/connection_banner.dart` | `ConnectionBanner`: "Sin conexión" + "Estás viendo datos de {ago}…" |
| "hace X" | `core/time/time_ago.dart` | `timeAgo(moment, now)` con textos fijos en español (pasa al ARB en la Parte 3) |
| Pantalla temporal | `core/ui/under_construction_screen.dart` | Hoy ocupa `/publicar`, `/por-revisar` y `/emergencia` |
| Rutas | `core/router/routes.dart`, `core/router/router.dart` | `Routes.home = '/'`, `publish = '/publicar'`, `toReview = '/por-revisar'`, `emergency`, `map` |
| Proveedores | `core/di/providers.dart` | `sessionProvider` (`LocalSession.demo`: Beto, zona piloto), `syncServiceProvider` (`FakeSyncService`), `syncStatusProvider`, `clockProvider`, `secureStoreProvider` |
| Estados de envío | `core/submissions/submission_status.dart`, `submission.dart` | `SubmissionStatus`, `RejectionReason { code, title, detail }`, `Accepted`, `Rejected`, `TransientFailure` |
| Muro | `features/solidaridad/` | `Post`, `PostType` (`offer`, `need`, `lend`, `donate`, `exchange`, `ride`, cada uno con `apiValue` en español), `PostStatus`, `NewPost`; `PostRepository`; casos de uso `PublishPost` y `TakeFavor` con `LocalValidationError`; `postRepositoryProvider` y `wallProvider`; `WallPage` y `PostCard` |
| Doble del servidor | `features/solidaridad/data/in_memory_post_repository.dart` | `InMemoryPostRepository` con `recordResponse(submissionId, result)` para simular 2xx, 409 o un fallo transitorio |
| Textos | `l10n/app_es.arb` | `appName`, `wallTitle`, `publishAction`, `takeFavorAction`, `statusSavedOnPhone`, `statusSavedOnPhoneDetail`, `offline`, `dataFrom`, `updatedAgo`, `actionsToReview`, `emergencyLifeRisk`, `connectsNeighbors`… |

Pruebas que ya existen: `test/widget_test.dart` (el muro abre; aviso sin conexión; el estado
tiene texto; texto al 200 %), `test/features/solidaridad/wall_offline_test.dart` y las de
`test/core/`. Míralas antes de escribir las tuyas.

### 0.3 Preparar el entorno

```bash
git clone https://github.com/stefanods29/Hackathon-ElComercio-Shabat-Shalom.git
cd Hackathon-ElComercio-Shabat-Shalom
git config user.name "<tu nombre>"
git config user.email "<tu correo de GitHub>"
cd app && flutter pub get && flutter gen-l10n && flutter test
```

Necesitas Flutter 3.47.9 y un Android real (para TalkBack y el dictado). El backend no hace
falta: todo se construye sobre los dobles en memoria.

### 0.4 Ciclo de cada parte

1. `git switch main && git pull` y luego `git switch -c lote-d/parte-<n>-<tema>`.
2. Implementa con pruebas de widgets.
3. **Compila y depura** desde `app/`:
   ```bash
   dart format lib test
   flutter gen-l10n && flutter analyze && flutter test
   flutter build apk --debug
   ```
   En Windows también sirve `tool\verify.cmd`. `flutter analyze` debe decir *No issues found*.
4. Revisa a mano en un Android con TalkBack encendido y con la letra del sistema al máximo.
5. Marca las tareas en `tasks.md`, sube la rama y abre el PR con el informe (sección 6).

---

## Parte 1 · Sistema de diseño accesible

Rama: `lote-d/parte-1-diseno` · Tareas 1.1–1.5 · Spec: `specs/app/accesibilidad/spec.md`

1. **Contraste verificado por prueba:**
   - `lib/core/theme/contrast.dart`: `double contrastRatio(Color a, Color b)` con la fórmula de
     WCAG (`(L1 + 0.05) / (L2 + 0.05)` sobre `Color.computeLuminance()`).
   - `test/core/theme/contrast_test.dart`: para `light()` y `dark()` comprueba ≥ 4,5 en
     `onSurface/surface`, `onPrimary/primary`, `onPrimaryContainer/primaryContainer`,
     `onSecondaryContainer/secondaryContainer`, `onTertiaryContainer/tertiaryContainer` y
     `onErrorContainer/errorContainer` (los usan los chips), y ≥ 3 en `outline/surface`. Si algún
     par falla, ajusta el esquema en `AccessibleTheme`, no la prueba.
2. **Tipografía legible:** agrega Atkinson Hyperlegible (licencia OFL) en `app/assets/fonts/`,
   declárala en `pubspec.yaml` y úsala en el tema. Registra la licencia en
   `app/assets/fonts/LICENSE.txt`.
3. **Componentes base en `lib/core/ui/`:**
   - `large_button.dart`: `LargeButton`, ícono + texto, ancho completo opcional, 48 dp como mínimo.
   - `notice_card.dart`: `NoticeCard`, el aviso destacado con ícono, título, detalle,
     `Semantics(liveRegion: true)` y colores del esquema.
   - Mueve `PostCard` a `features/solidaridad/presentation/widgets/post_card.dart` con una etiqueta
     semántica que una tipo, título y estado. TalkBack debe leer, por ejemplo: "Necesito. Necesito
     dos bidones de agua. Guardado en tu celular".
4. **Golden tests** en `test/goldens/wall_page_golden_test.dart`: el muro en claro y oscuro con
   `TextScaler.linear(1.0)` y `2.0`, sin desbordes. Carga la fuente real en
   `test/flutter_test_config.dart` con `FontLoader`. Etiqueta estas pruebas con `golden`
   (`dart_test.yaml`) y genera las referencias **solo en Linux**
   (`flutter test --update-goldens --tags golden`, en CI o en WSL), porque las fuentes cambian
   entre sistemas. Las imágenes aprobadas se suben en el mismo commit.
5. **Pruebas de accesibilidad** sobre `WallPage`:
   `expectLater(tester, meetsGuideline(androidTapTargetGuideline))`, también
   `iOSTapTargetGuideline`, `labeledTapTargetGuideline` y `textContrastGuideline`.
6. **Modo sencillo:**
   - `lib/core/ui/simple_mode.dart`: `simpleModeProvider` (`NotifierProvider<…, bool>`),
     persistido con `shared_preferences` (`flutter pub add shared_preferences`).
   - Al activarlo: texto 1,3 veces más grande (multiplicando el `textScaler` del sistema), se
     ocultan las acciones secundarias (bandeja) y quedan solo el muro y "Publicar". Se usa el
     **mismo widget con parámetros**, no pantallas paralelas.
   - Se activa desde un menú en la barra superior ("Modo sencillo"). Prueba de widgets: al
     activarlo, el inicio muestra solo el muro y el botón de publicar.

---

## Parte 2 · Publicar en 3 toques

Rama: `lote-d/parte-2-publicar` · Tareas 2.1–2.5 · Spec: `specs/app/publicar-en-tres-toques/spec.md`

1. **Flujo:**
   - Toque 1: el botón "+" del muro, que ya existe y lleva a `/publicar`.
   - Toque 2: elegir el tipo en una grilla de `LargeButton` con ícono y texto: Ofrezco, Necesito,
     Presto, Dono, Intercambio y Movilidad. Lleva a `/publicar/:tipo`, con `PostType.apiValue`
     en la ruta.
   - Toque 3: "Publicar" en el formulario mínimo **prellenado y válido tal como aparece**.
2. **Archivos en `lib/features/publicar/`:**
   - `domain/suggestions.dart`: sugerencias por tipo. Los títulos deben tener de 3 a 120
     caracteres y las categorías de 2 a 40, para que el tercer toque funcione sin escribir nada.
     Por ejemplo: `need` → categoría `ayuda`, título "Necesito ayuda en mi cuadra"; `lend` →
     `herramientas`, "Presto herramientas"; `donate` → `ropa`, "Dono ropa en buen estado";
     `offer` → `servicios`, "Ofrezco ayuda a mis vecinos"; `exchange` → `intercambio`,
     "Intercambio cosas que ya no uso"; `ride` → `movilidad`, "Ofrezco movilidad". Los textos
     van al ARB.
   - `presentation/choose_type_page.dart` y `presentation/publish_form_page.dart`: el título con
     `autofocus` y el cursor al final (lo pide el spec), chips de categoría con la sugerida
     marcada y descripción opcional. La ubicación aproximada queda para después de la Fase 0.
3. **Guardar:** `PublishPost(ref.read(postRepositoryProvider)).execute(NewPost(...))` y luego
   `context.go(Routes.home)`. El muro muestra la publicación al instante con *Guardado en tu
   celular*, aunque no haya conexión.
4. **Errores junto al campo:** agrega a `LocalValidationError` el campo opcional
   `field` (`'title'`, `'category'` o `'description'`), sin romper a quien ya lo usa, y muestra
   el mensaje en el `errorText` del campo. Ejemplo exigido por el spec: título de 2 letras → "El
   título debe tener entre 3 y 120 caracteres." junto al campo, y no se encola nada.
5. **Rutas:** en `core/router/router.dart` cambia `UnderConstructionScreen` de `/publicar` por
   `ChooseTypePage` y agrega `/publicar/:tipo` (en `routes.dart`, `publishForm`).
6. **Dictado por voz (opcional, tarea 2.4):** `flutter pub add speech_to_text`. Un botón "Dictar"
   con etiqueta semántica junto al título. Permisos: `RECORD_AUDIO` y la consulta del
   `RecognitionService` en `AndroidManifest.xml`; `NSSpeechRecognitionUsageDescription` y
   `NSMicrophoneUsageDescription` en `Info.plist`, con textos en español. Si el permiso se niega,
   el botón explica cómo activarlo y el formulario sigue funcionando.
7. **Pruebas:**
   - Una prueba de widgets que cuente **exactamente 3** `tester.tap` desde el muro hasta ver la
     publicación nueva con *Guardado en tu celular*.
   - Validación por campo (título corto, categoría vacía, descripción de más de 2 000 caracteres).
   - Publicar con `FakeSyncService(SyncStatus(connected: false))`: vuelve al muro con el aviso.

---

## Parte 3 · Estados visibles y "acciones por revisar"

Rama: `lote-d/parte-3-estados` · Tareas 3.1–3.4 · Spec: `specs/app/visibilidad-de-estados/spec.md`

1. **Aviso destacado de lo no enviado:** en `PostCard`, si `submissionStatus == savedOnPhone`,
   muestra un `NoticeCard` con "Guardado en tu celular · Todavía no se envió. Nadie más lo ha
   recibido." (claves que ya existen: `statusSavedOnPhone` y `statusSavedOnPhoneDetail`).
2. **Contador de pendientes:** una insignia en el ícono de la bandeja con
   `syncStatusProvider.pendingUploads`, que el Lote A llenará con datos reales. Pruébalo
   sobreescribiendo `syncServiceProvider` con `FakeSyncService(SyncStatus(…, pendingUploads: 2))`.
   No leas los envíos del doble en memoria desde la UI.
3. **"Actualizado hace X" con plurales:**
   - Lleva los textos de `timeAgo` al ARB con plurales ICU: `timeAgoMoment`,
     `timeAgoMinutes` (`{count, plural, =1{hace 1 minuto} other{hace {count} minutos}}`),
     `timeAgoHours` y `timeAgoDays`.
   - `timeAgo` recibe `AppLocalizations`. Actualiza `ConnectionBanner` y
     `test/core/time/time_ago_test.dart`, usando `lookupAppLocalizations(const Locale('es'))` en
     las pruebas.
   - Muestra "Actualizado {ago}" (clave `updatedAgo`) debajo de la barra del muro, con
     `syncStatus.lastSyncedAt`.
4. **Bandeja "Acciones por revisar"** en
   `features/solidaridad/presentation/actions_to_review_page.dart`, ocupando `/por-revisar` en
   lugar de `UnderConstructionScreen`:
   - Proveedor `actionsToReviewProvider = StreamProvider((ref) =>
     ref.watch(postRepositoryProvider).watchActionsToReview())`.
   - Cada elemento muestra qué se intentó (el título de la publicación, buscado por `resourceId`
     en `wallProvider`), el motivo del servidor (`rejectionReason.title` y `detail`) y **una
     alternativa según `rejectionReason.code`**:
     | `code` | Alternativa |
     |---|---|
     | `favor_no_disponible` | "Otro vecino llegó primero. Busca otro favor en el muro." + botón al muro |
     | `conflicto_de_version` | "La publicación cambió. Revísala y vuelve a intentarlo." |
     | `nivel_de_confianza_insuficiente` | "Primero confirma que vives en la zona." |
     | `fuera_de_tu_zona` | "Solo puedes tomar favores de tu zona." |
     | cualquier otro | "Revisa los datos y vuelve a intentarlo." |
   - Estado vacío: "No tienes acciones por revisar."
5. **Pruebas:** simula el 409 con `InMemoryPostRepository.recordResponse(submission.id,
   const Rejected(RejectionReason(code: 'favor_no_disponible', title: 'Conflicto')))` y comprueba
   que la tarjeta vuelve a estar disponible, la bandeja muestra el motivo y la alternativa, y el
   aviso de lo no enviado desaparece cuando llega `Accepted()`.

---

## Parte 4 · Tutorial y modo práctica

Rama: `lote-d/parte-4-tutorial` · Tareas 4.1–4.4 · Spec: `specs/app/tutorial/spec.md`

1. `flutter pub add showcaseview`. **Revisa el README de la versión instalada**: la API cambió
   entre versiones mayores (`ShowCaseWidget`/`Showcase` antes, registro con `ShowcaseView` en las
   recientes).
2. **Primera vez:** la bandera `tutorialSeen` se guarda con `shared_preferences` detrás de un
   proveedor, para poder probarla. El tutorial se puede **saltar** y **repetir** desde el menú
   ("Ver tutorial").
3. **Pasos sobre la pantalla real** (`lib/features/onboarding/`):
   1. El botón "+": "Toca aquí para publicar en 3 toques."
   2. "Tomar favor" en una tarjeta.
   3. El estado *Guardado en tu celular*: "Lo guardado en tu celular todavía no le llega a nadie.
      Se envía cuando vuelve la señal."
   4. La bandeja "Acciones por revisar".
   5. El cierre: "Si hay riesgo para la vida, llama al 116, 105 o 106." y "Esta app conecta
      vecinos; no reemplaza a los servicios de emergencia." (claves `emergencyLifeRisk` y
      `connectsNeighbors`).
4. **Modo práctica:**
   - `practiceModeProvider` (bool). Mientras está activo, la parte de la app que se practica va
     dentro de un `ProviderScope` anidado que sobreescribe `postRepositoryProvider` con **otra**
     instancia de `InMemoryPostRepository`, con publicaciones de ejemplo. Nada llega al
     repositorio real.
   - Una franja fija "Modo práctica: nada de lo que hagas se envía" y la etiqueta "De práctica"
     en las tarjetas en lugar del chip de estado.
   - Prueba: con un repositorio real espía, publicar y tomar favores en modo práctica **no** le
     agrega ningún envío.
5. **Textos:** todos en el ARB. La tarea 4.3 pide que el equipo los revise; deja la lista de
   textos en el informe.
6. **Pruebas de widgets:** el tutorial aparece la primera vez, se salta, no vuelve a aparecer y se
   repite desde el menú.

---

## Parte 5 · Inicio de sesión, zona y cuenta

Rama: `lote-d/parte-5-sesion-y-cuenta` · Tareas 5.1–5.6 · Spec: `specs/app/inicio-de-sesion-y-cuenta/spec.md`

1. **Puerto y estado** en `lib/features/cuenta/` (carpeta nueva):
   - `domain/auth_state.dart`: `sealed class AuthState` con `SignedOut`, `NeedsZone(user)` y
     `SignedIn(user)`.
   - `domain/auth_repository.dart`: el puerto `AuthRepository` con `watch()` (un
     `Stream<AuthState>`), `requestCode(phone)` (devuelve `CodeRequest { retryAfterSeconds,
     expiresInSeconds }`), `verifyCode(phone, code)`, `listZones()`, `chooseZone(zoneId)`,
     `signOut()` y `signOutEverywhere()`. Errores tipados `InvalidCode` y
     `TooManyAttempts(retryAfterSeconds)`, que reflejan los códigos de la API del Lote B
     (`codigo_invalido` y `demasiados_intentos`).
   - `data/in_memory_auth_repository.dart`: el doble. **Por defecto arranca en `SignedIn` con la
     sesión de demostración** (Beto, zona piloto), para que el resto de la app y las pruebas
     actuales sigan igual; las pruebas de este flujo lo crean en `SignedOut`. El código correcto
     es `123456`, y 5 errores seguidos dan `TooManyAttempts(900)`.
   - `data/providers.dart`: `authRepositoryProvider` y `authStateProvider`. `sessionProvider`
     (`core/di/providers.dart`) pasa a derivarse de `SignedIn`. El Lote A sobreescribe
     `authRepositoryProvider` con la versión real (tarea 2.5 de su change).
2. **Pantallas** en `lib/features/cuenta/presentation/`:
   - `phone_page.dart` (`/ingresar`): prefijo +51 por defecto, teclado numérico, validación del
     formato antes de enviar y una línea de privacidad ("Usaremos tu número solo para que entres a
     la app."). El consentimiento completo y los derechos ARCO llegan en la Fase 1.
   - `code_page.dart` (`/ingresar/codigo`): campo de 6 dígitos con `AutofillHints.oneTimeCode`,
     "Reenviar código en {seconds} s" con cuenta regresiva desde `retryAfterSeconds`, y errores
     junto al campo: "El código no es correcto o ya venció." y "Demasiados intentos. Prueba de
     nuevo en {minutes} min.", con el botón desactivado mientras tanto.
   - `choose_zone_page.dart` (`/elegir-zona`): lista de zonas (nombre y distrito) con botones
     grandes; al elegir, va al muro.
   - `account_page.dart` (`/cuenta`): nombre, teléfono y zona; interruptor "Modo sencillo"
     (Parte 1); "Ver tutorial" (Parte 4); "Cerrar sesión" con un diálogo que avisa "Se borrarán
     los datos guardados en este celular."; y "Perdí mi teléfono: cerrar sesión en todos mis
     dispositivos", con confirmación.
   - Acceso a "Mi cuenta" desde el menú de la barra superior del muro.
3. **Router:** un `redirect` de go_router según `authStateProvider`: `SignedOut` → `/ingresar`;
   `NeedsZone` → `/elegir-zona`; `SignedIn` en una ruta de ingreso → `/`. Agrega en `routes.dart`
   `signIn`, `signInCode`, `chooseZone` y `account`, con caminos en español.
4. **Textos** en `app_es.arb`, con claves en inglés: `signInTitle`, `phoneLabel`, `sendCode`,
   `codeLabel`, `resendCodeIn`, `invalidCode`, `tooManyAttempts`, `chooseZoneTitle`,
   `accountTitle`, `signOut`, `signOutWarning`, `lostPhone` y `lostPhoneConfirm`.
5. **Pruebas de widgets** con el doble: teléfono → código errado (mensaje) → código correcto →
   elegir zona → muro; demasiados intentos (botón desactivado y minutos); cerrar sesión vuelve a
   `/ingresar`; y sin sesión el muro no se ve. Todas con letra al 200 % y objetivos de 48 dp.

---

## 5. Puntos de contacto con otros lotes

| Con | Qué | Regla |
|---|---|---|
| Lote A | `PostRepository`, `SyncService`, `Submission` y "acciones por revisar" | D usa los dobles; A cambia los proveedores. Las interfaces no cambian sin acordarlo |
| Lotes A y B | `AuthRepository` (Parte 5) | D define el puerto, las pantallas y el doble; B hace la API (`/v1/auth/*`, `/v1/zonas`, `/v1/yo/zona`); A conecta la versión real |
| Lote C | `/mapa` y el detalle `/publicaciones/:id` | C entrega las pantallas; D revisa su accesibilidad y aplica los componentes base |
| Todos | `core/router/router.dart`, `app_es.arb`, `pubspec.yaml`, `android/` e `ios/` (permisos) | Cambios pequeños; rebase antes de entregar |

## Fuera de alcance

El directorio de emergencia y el botón "Estoy en emergencia" (Fase 1), el tablero humanitario
(Fase 2), el quechua (Fase 3), la lógica de sincronización (Lote A) y los mapas (Lote C).

## 6. Informe de entrega (descripción del PR de cada parte)

```text
Lote D · Parte N · <tema>
Rama: lote-d/parte-N-<tema> · PR: #<número>
Qué cambió (pantallas, componentes, textos): …
Paquetes nuevos: …
Verificación: dart format ✔ · analyze sin avisos ✔ · flutter test ✔ (N pruebas) · goldens ✔ · apk ✔
Revisión manual: TalkBack ✔ · letra al máximo ✔ (dispositivo y versión)
Tareas marcadas: N.1 … N.k
Puntos de contacto tocados: …
Riesgos o pendientes: …
```

## 7. Definición de terminado del lote

Las 5 partes aprobadas e integradas, el inicio de sesión con elección de zona y la cuenta, publicar en exactamente 3 toques, los estados siempre
visibles, la bandeja con alternativas, el tutorial con modo práctica, los goldens con texto al
200 % aprobados y el change listo para archivarse.
