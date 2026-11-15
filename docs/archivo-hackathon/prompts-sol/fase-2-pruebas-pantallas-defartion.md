# Encargo para Defartion: pruebas de pantallas del tablero (D) y de la consola (C)

Hola, Defartion. La Fase 2 ya está integrada en `main` (commit `0c6489d` o posterior) y toda su CI
está en verde. Tu módulo Emergencias (Lote B) funciona de punta a punta contra PostgreSQL. Este
encargo cierra dos pendientes que no necesitan celulares: las pruebas de pantallas del tablero de
emergencia de la app (Lote D) y las de la consola web (Lote C).

En paralelo, en otras ramas, se están escribiendo las pruebas de escalamiento y supresión de tu
Lote B (`f2-lote-b/parte-3-4-pruebas`) y la frescura de los recursos del tablero
(`f2-lote-d/parte-3-frescura`). La sección "Para no pisarse" dice qué archivos no tocar.

## Antes de empezar

Lee, en este orden:

1. `reglas-de-trabajo.md` y los `AGENTS.md` aplicables.
2. `docs/fase-2/integracion.md`: qué se conectó entre lotes y qué se decidió. No reabras esas
   decisiones; si no estás de acuerdo con alguna, dilo en la entrega.
3. `docs/fase-2/lote-d-tablero-de-emergencia/README.md` (partes 1 y 2) e `integracion.md`.
4. `docs/fase-2/lote-c-consola-web-y-avisos-urgentes/README.md` e `integracion.md` (la tabla
   "Pruebas por escribir").
5. Los `tasks.md` de `openspec/changes/fase-2-lote-d-tablero-de-emergencia/` y
   `fase-2-lote-c-consola-web-y-avisos-urgentes/`.

Herramientas: Flutter 3.47, Node 26 y [OpenTofu](https://opentofu.org/docs/intro/install/) para la
parte de infraestructura (`brew install opentofu` en macOS).

## Reglas de la entrega

1. Dos ramas nuevas desde `main` actualizado, una por encargo:

   ```bash
   git fetch origin
   git switch -c f2-lote-d/parte-1-2-pruebas-pantallas origin/main
   # y, para el segundo encargo:
   git switch -c f2-lote-c/parte-1-2-pruebas-pantallas origin/main
   ```

2. Commit y push **solo de tu rama** (`git push -u origin <rama>`). Nada de merge, rebase,
   cherry-pick ni PR. No toques `main` ni borres ramas.
3. En responsables, autores o revisores solo van usuarios de GitHub del equipo: `JDiazD33`,
   `stefanods29`, `Defartion`, `KQuirosA`. Nunca el nombre de un agente, modelo o herramienta.
   Ninguna mención de herramientas de IA en commits, código ni documentos, y ninguna línea
   `Co-Authored-By`. No cambies los responsables de las tablas de estado.
4. Marca una tarea `[x]` solo con evidencia: la prueba que la cubre pasando y el comando que la
   corrió. Lo que no se pueda probar se queda abierto, con el motivo.
5. Datos de prueba siempre ficticios. Nada de credenciales, teléfonos reales ni ubicaciones reales.
6. Las pruebas no deben cambiar el comportamiento de las pantallas. Si una prueba revela un error,
   arréglalo en el mismo commit que la prueba que lo demuestra y explícalo en la entrega.
7. Textos en español de Perú, código en inglés (ADR 0007). Si agregas un texto visible, va en el
   ARB (`app/lib/l10n/app_es.arb` o `consola/lib/l10n/app_es.arb`).

## Para no pisarse

En la otra rama de D se modifican `app/lib/features/emergencias/domain/emergency.dart`,
`data/operational_emergency_repository.dart` y `CriticalResourceCard` en
`presentation/emergency_resource_pages.dart`. No los cambies. Si necesitas tocarlos para arreglar un
error, avisa en la entrega en lugar de hacerlo. Tus archivos nuevos van en `app/test/features/emergencias/`
y `consola/test/`.

## Encargo 1 · Lote D: pantallas del tablero de emergencia

Rama `f2-lote-d/parte-1-2-pruebas-pantallas`. Cierra D **1.3** y **2.3**.

### Qué hay

| Pantalla | Archivo |
|---|---|
| Tablero de inicio | `app/lib/features/emergencias/presentation/emergency_dashboard_page.dart` (`EmergencyDashboardPage`) |
| Tipo de necesidad, formulario y pedido propio | `presentation/help_request_pages.dart` (`EmergencyNeedsPage`, `HelpRequestFormPage`, `OwnHelpRequestPage`) |
| Alternativas oficiales y puerta de la cuenta | `presentation/emergency_widgets.dart` (`EmergencyAlternatives`, `EmergencyScopeGate`) |
| Puerto y dobles | `domain/emergency.dart` (`EmergencyRepository`, `UnavailableEmergencyRepository`) y `data/emergency_providers.dart` (`PracticeEmergencyRepository`, `emergencyRepositoryProvider`, `emergencyScopeProvider`, `emergencyHomeProvider`) |
| Rutas | `app/lib/core/router/routes.dart` (`/emergencia/tablero`, `/emergencia/necesito`, `/emergencia/nuevo/:need`, `/emergencia/pedidos/:id`) |

Los textos están en `app/lib/l10n/app_es.arb`, por ejemplo `emergencyNoCoverage`,
`emergencyLifeRisk`, `emergencyRequestLocalHelp` ("Tu pedido todavía no fue enviado. Nadie lo ha
recibido…"), `emergencyRequestSentHelp`, `emergencyRequestSeenHelp`, `emergencyRequestOnTheWayHelp`,
`emergencyRequestAttendedHelp`, `emergencyRequestReferred` y `emergencyRequestClosedHelp`. En las
pruebas busca por el texto del ARB; no copies cadenas a mano.

Modelos de prueba que ya existen: `help_request_status_card_test.dart` (texto de cada estado),
`operational_emergency_repository_test.dart` (repositorio real con base local) y
`test/features/directorio/directory_page_test.dart` (página con `ProviderScope`).

Para controlar lo que ve la pantalla, sobrescribe `emergencyRepositoryProvider` con un doble que
implemente `EmergencyRepository` y emita los `EmergencySnapshot` que necesites: con o sin
`coverageVerified`, con `activeEvent` y con pedidos en cada `HelpRequestStatus`. Sobrescribe también
`emergencyScopeProvider` con un `EmergencyScope` de cuenta real (`practice: false`) o de práctica, y
`clockProvider` con un reloj fijo.

### 1.3 Inicio en modo emergencia

Pruebas de widgets:

- **Zona sin cobertura:** con `coverageVerified: false` se ve `emergencyNoCoverage`, las
  alternativas oficiales (116, 105 y 106) están visibles y "Necesito ayuda" y "Puedo ayudar" no
  están disponibles (`onPressed == null`).
- **Evento activo:** con `activeEvent: true`, `emergencyHomeProvider` es verdadero y el inicio
  muestra el tablero. Hazlo con el router de la app o con el proveedor, según lo que use el inicio.
- **Modo manual:** encender el modo emergencia con el botón de `EmergencyPage` (`appModeProvider`)
  lleva al tablero y apaga las imágenes (`imagesEnabledProvider` falso, sin poder encenderlas).

### 2.3 "Necesito ayuda" y el estado de mi pedido

- **Tres toques contados:** desde el tablero, toque 1 en "Necesito ayuda", toque 2 en el tipo de
  necesidad, escribir la descripción (no cuenta como toque) y toque 3 en "Enviar". Cuenta los
  `tester.tap` y verifica que se llamó a `saveRequest` una sola vez, con el id y la clave del
  borrador. Repite el envío y comprueba que no se duplica.
- **Cada estado con su mensaje:** para `local`, `sent`, `seen`, `onTheWay`, `attended`, `referred`
  y `closedUnattended`, `OwnHelpRequestPage` muestra su texto del ARB. Las alternativas oficiales
  siguen visibles en todos. En `onTheWay` no aparece ningún dato de quien ayuda, y solo con
  `canConfirmAttendance: true` aparece el botón de confirmar la atención.
- **Derivado y cerrado con motivo:** se muestra `reason` y el paso siguiente (`nextStep`).
- **Sin señal (simulado):** con la sincronización desconectada (`syncStatusProvider` o
  `FakeSyncService` como en `directory_page_test.dart`) y un pedido sin acuse, la pantalla dice que
  no fue enviado y muestra el aviso sin conexión. Es la prueba en modo avión **a nivel de widget**.
  La de las pantallas en un celular o simulador es la tarea A 1.5, que sigue abierta: no la marques.
- **Práctica aislada:** en el modo de práctica el pedido queda local, nunca pasa a `sent` y no se
  abre el compositor de SMS con destinatarios reales.

### Verificación del Encargo 1

```bash
cd app
tool/verify.sh
```

Si pasa, marca D 1.3 y 2.3. En la nota de 2.3 aclara que el modo avión probado es simulado en el
widget.

## Encargo 2 · Lote C: pantallas de la consola y OpenTofu

Rama `f2-lote-c/parte-1-2-pruebas-pantallas`. Cierra C **1.7** y **2.6**.

La consola tiene hoy pruebas de sus adaptadores HTTP (`consola/test/features/http_operational_repositories_test.dart`)
y del contrato en vivo (`consola/test/live/`, que se salta sin `VECINAL_API_FIXTURE`). Le faltan las
de pantallas. Usa los datos de demostración (`DemoCasesRepository` y los otros repositorios demo) o
dobles propios. Ninguna prueba hace peticiones de red reales.

### Pruebas de unidad

Las de la tabla "Pruebas por escribir" de `docs/fase-2/lote-c-consola-web-y-avisos-urgentes/integracion.md`:
`markFor`, `sortQueue`, `actionsFrom`, `showsExactLocation`, `CellCount`, `coverageOf`,
`validateEntry`, `suggestId`, `normalizePhone` y `SessionTokens.fromJson`, cada una con sus bordes:

- `markFor`: el 25 % y los 5 minutos que quedan, el plazo vencido y la prioridad baja sin plazo.
- `CellCount`: 0, 2 y 3.
- `normalizePhone` y `SessionTokens.fromJson`: datos válidos y maliciosos.

### Pruebas de widgets

- **Ingreso:** una cuenta sin rol operativo verifica su código y la consola cierra la sesión y lo
  explica (`features/ingreso/sign_in_page.dart`, `core/session/`).
- **Inactividad:** el aviso aparece antes del cierre y la sesión se cierra al vencer
  (`core/session/inactivity_guard.dart`), con un reloj controlado (`core/time/clock.dart`).
- **Cola:** con texto al 200 % (`MediaQuery` con `textScaler: TextScaler.linear(2)`) no hay
  desbordes. Se recorre y se abre un caso solo con el teclado (Tab y Enter) y el foco es visible
  (`features/casos/presentation/cases_queue_page.dart`).
- **Errores:** cada `codigo` conocido de `explainProblem` muestra su texto
  (`core/ui/problem_notice.dart`), y un 409 en el diálogo de acción conserva lo escrito
  (`case_action_dialog.dart`).
- **Celdas:** la tabla muestra «menos de 3» y sin columna de total cuando la API no publica totales
  (`cells_page.dart`). El mapa usa MapLibre y puede no dibujarse en `flutter test`: prueba la tabla y
  `cellsGeoJson`, no el mapa.
- **Moderación:** la decisión viaja con `Idempotency-Key` (`moderacion/presentation/moderation_page.dart`).
- **Avisos urgentes:** el banner muestra los pendientes y confirmar llama a la ruta de confirmación
  (`avisos_urgentes/presentation/urgent_notices_banner.dart`).

### Infraestructura

```bash
tofu -chdir=infra/cloud/modules/console-site init -backend=false
tofu -chdir=infra/cloud/modules/console-site validate
tofu -chdir=infra/cloud fmt -check -recursive
```

Si `validate` falla, corrige el módulo y explica el cambio. No agregues proveedores reales, cuentas
ni secretos: el despliegue sigue esperando `CLOUDFLARE_API_TOKEN` y `CLOUDFLARE_ACCOUNT_ID`.

### Verificación del Encargo 2

```bash
cd consola
flutter pub get && flutter gen-l10n
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed lib test
tool/vendor_maplibre.sh
flutter build web --release --no-web-resources-cdn --dart-define=CONSOLE_DATA=demo
```

Marca C 1.7 si pasa todo eso y `tofu validate`; la CI en verde la revisamos al integrar. Marca C 2.6
si pasan las pruebas de la cola y del diálogo.

## Entrega

Para cada rama, devuelve:

- Nombre de la rama y SHA final (ya subida con `git push -u origin <rama>`).
- Archivos nuevos o cambiados y por qué. Si arreglaste un error, cuál y qué prueba lo demuestra.
- Comandos corridos con su resultado, incluida la cantidad de pruebas que pasan.
- Tareas marcadas y las que quedan abiertas, con el motivo.
- Dudas o desacuerdos con `docs/fase-2/integracion.md`, sin cambiarlo por tu cuenta.
