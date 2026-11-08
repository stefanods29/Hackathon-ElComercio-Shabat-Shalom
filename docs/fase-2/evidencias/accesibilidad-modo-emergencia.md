# Accesibilidad automática del modo emergencia

Fase 2, Lote D, tarea 4.2 (parte automática). Verificado el 8 de noviembre de 2026 con Flutter 3.47
sobre `main`.

```bash
cd app
flutter test test/features/emergencias/emergency_accessibility_test.dart
```

## Qué cubre

Seis pantallas: tablero, tipo de necesidad, formulario, pedido propio, recursos y contactos. Las
pruebas usan una cuenta de práctica con un pedido en camino y recursos ficticios.

| Comprobación | Cómo | Resultado |
|---|---|---|
| Texto grande | Texto al 200 %, sin desbordes ni excepciones | Pasa en las 6 |
| Botones grandes y con nombre | `androidTapTargetGuideline` (48 dp), `iOSTapTargetGuideline` (44 pt) y `labeledTapTargetGuideline` al 200 % | Pasa en las 6 |
| Contraste del texto | `textContrastGuideline` (WCAG) en tema claro y oscuro | Pasa en las 6 |
| Modo sencillo | El texto crece sin desbordes y la preferencia queda guardada | Pasa en las 6 |
| Orden del lector de pantalla | Recorrido simulado: el tablero empieza por su título y "Necesito ayuda" va después; en el pedido propio el estado se lee antes que las alternativas oficiales | Pasa |
| Referencias visuales (goldens) | Una imagen por pantalla al 200 % | Pasa en la verificación original de macOS |

Resultado original de macOS sobre `main`: 33 de 33, y `tool/verify.sh` en verde con 284 pruebas.
Los resultados de esta rama se registran aparte en la sección siguiente.

Las imágenes de referencia usan la fuente de prueba de Flutter, que dibuja las letras como bloques,
y muestran el diseño, no la tipografía. El suavizado difiere entre sistemas: por eso cada sistema
tiene seis referencias propias, seleccionadas con `Platform.operatingSystem`. La tolerancia sigue
siendo del 1 %. Linux y macOS comparan las imágenes; cualquier otro sistema salta solo esos seis
casos e informa que no tiene referencias. Las otras 27 comprobaciones se ejecutan en todos.

## Generación y verificación por sistema

Rama `f2-ci/referencias-linux`, a partir de `4fb7761a52d2762911dbfb02ea5b7c9e25781d26`.
Las seis imágenes anteriores se trasladaron a `goldens/macos/` sin modificar sus bytes.
Las de `goldens/linux/` se generan en Ubuntu 26.04 con Flutter 3.47.9. El [run de integración
42491614262](https://github.com/stefanods29/Hackathon-ElComercio-Shabat-Shalom/actions/runs/42491614262)
registra Ubuntu 26.04.1 e imagen `ubuntu-26.04` (`ubuntu26/20261101.186`); esta rama fija
`runs-on: ubuntu-26.04` para conservar ese sistema aunque cambie el alias `ubuntu-latest`.
La imagen de `infra/flutter/Dockerfile`
descarga el SDK oficial y valida su SHA-256; incluye Dart 3.13.7.

Desde la raíz del repositorio, en Bash:

```bash
docker build --platform linux/amd64 -t vecinal-flutter:3.47.9-ubuntu26 -f infra/flutter/Dockerfile .
docker run --rm --platform linux/amd64 -v "$PWD:/workspace" -v vecinal-flutter-pub:/opt/pub-cache \
  vecinal-flutter:3.47.9-ubuntu26 bash -c \
  'flutter pub get && flutter gen-l10n && flutter test --update-goldens test/features/emergencias/emergency_accessibility_test.dart'
docker run --rm --platform linux/amd64 -v "$PWD:/workspace" -v vecinal-flutter-pub:/opt/pub-cache \
  vecinal-flutter:3.47.9-ubuntu26 bash tool/verify.sh
```

En PowerShell, reemplazar `$PWD` por `${PWD}` en las rutas y usar el acento grave para continuar
líneas, o ejecutar cada comando en una sola línea. La caché de dependencias queda en el volumen
local `vecinal-flutter-pub`, fuera del repositorio.
La imagen usa el SDK Linux x64; `--platform linux/amd64` mantiene esa arquitectura también al
reproducirla desde una Mac con Apple Silicon.

En macOS, con Flutter 3.47.9:

```bash
cd app
flutter test --update-goldens test/features/emergencias/emergency_accessibility_test.dart
bash tool/verify.sh
```

Revisar visualmente las seis imágenes antes de guardar nuevas referencias. Regenerarlas solo
ante un cambio de diseño aprobado; la comparación normal no usa `--update-goldens`.
El job `ios` ejecuta también `tool/verify.sh`, de modo que un `workflow_dispatch` de `app.yml`
verifica ambos juegos de referencias además de compilar Android e iOS.

### Evidencia local del 8 de noviembre de 2026

Entorno del contenedor: Ubuntu 26.04.1 LTS, Flutter 3.47.9 (`c197ca5199`),
motor `89c39edfdf`, Dart 3.13.7.

| Comprobación | Resultado |
|---|---|
| Prueba de accesibilidad con generación de Linux | `+33: All tests passed!`; se generan las seis imágenes |
| Segunda generación en un contenedor nuevo | `+33: All tests passed!`; `sha256sum --check` devuelve `OK` para las seis |
| Variación entre ambas generaciones | 0 %: los seis archivos son idénticos byte por byte; tolerancia conservada en 1 % |
| Referencias de macOS trasladadas | Los seis hashes de los blobs coinciden con los de `main` antes del traslado |
| `bash tool/verify.sh` en el contenedor de Ubuntu | `No issues found!`; `+284 ~1: All tests passed!`; 223 archivos, 0 cambios de formato; `✓ App verificada` |

La segunda corrida guarda primero `sha256sum test/features/emergencias/goldens/linux/*.png`
en un archivo temporal, regenera con `--update-goldens` y comprueba ese archivo con
`sha256sum --check`. Se revisaron visualmente las seis referencias; usan la fuente de prueba
esperada y no contienen marcas de desbordamiento.

## Lo que no cubre

- Recorrer las pantallas con TalkBack y VoiceOver en un teléfono (tarea D 4.5).
- El alto contraste del sistema operativo: las pruebas comprueban el contraste de los temas de la
  app, no la opción del teléfono.
- La prueba con vecinos del simulacro (D 4.3).

## Teléfonos reales

Preparación del 8 de noviembre de 2026, America/Lima, en
`f2-lote-a/parte-3-y-d-4-telefonos`, desde `origin/main` en `4fb7761`.
Responsable del recorrido y de las observaciones: `JDiazD33`.

D 4.5 sigue abierta hasta registrar el recorrido con el lector y el contraste del sistema en ambos
teléfonos. La [guía Android](telefonos-android.md#3-d-45-talkback-texto-grande-y-contraste) y la
[guía de iPhone](telefonos-ios.md#d-45--voiceover-texto-grande-y-contraste) describen los ajustes,
los pasos y los límites de práctica. Consultar el [reporte inicial de Android](reporte-telefonos-android.md).

| Registro | Android | iPhone |
|---|---|---|
| Modelo y versión del sistema | POCO X6 Pro informado por el usuario; ADB confirma Xiaomi `2311DRK48G`, Android 16, API 36 | iPhone XR, iOS 17.7, detectado por Xcode mediante USB |
| Versión de TalkBack/VoiceOver | `17.1.0.1003738110`, consultada en el dispositivo | No probado |
| Teclado y dictado del sistema | Pendiente | No probado |
| Tamaño de fuente y contraste del sistema | Consulta inicial: `font_scale=1.1` (110 %); `high_text_contrast_enabled` sin valor definido. No se atribuye al teléfono el 200 % de los widgets | No configurado |
| Modo sencillo, tema y sesión usados | Práctica confirmada por el usuario; modo sencillo y tema de la ejecución pendientes | No ejecutado |
| Fecha y commit instalado | 8 de noviembre de 2026; base `4fb7761` más entrada de práctica de esta rama. APK de práctica instalado y actividad abierta por ADB; integridad en el reporte | 8 de noviembre de 2026, `e658974`. Variante de práctica compilada, firmada e instalada por USB con un identificador de laboratorio |
| Observación física recibida | El usuario confirma la franja «Modo práctica», el acceso con «Estoy en emergencia» y la identificación de «Volver al inicio normal»; pendiente del recorrido con lector | La Mac confirmó el arranque de la entrada de práctica y el muro. El responsable pospuso el recorrido con VoiceOver |

La confirmación de arranque y navegación corresponde a la variante de práctica del commit
`5f4ec140097e2cc4093c6eaea3d83578747cbba7`, el 8 de noviembre de 2026. No se confirmó que TalkBack
estuviera activo ni se comunicaron anuncios del lector; por ello los pasos D-01 a D-11 conservan
su estado pendiente. Se mantuvo la navegación existente al identificarse el control de salida.

| Paso | Esperado | Observado en Android | Resultado |
|---|---|---|---|
| D-01 · Título y orden | El recorrido comienza por el título del tablero | No ejecutado | Pendiente |
| D-02 · Acciones | Los cuatro botones tienen nombre y función comprensibles | No ejecutado | Pendiente |
| D-03 · Alternativas | Se lee el recordatorio de riesgo para la vida y los números oficiales | No ejecutado | Pendiente |
| D-04 · Tres activaciones | Tablero → necesidad → formulario → guardar, con cada paso anunciado | No ejecutado | Pendiente |
| D-05 · Dictado del teclado | Se puede completar, corregir y regresar al formulario usando TalkBack | No ejecutado | Pendiente |
| D-06 · Pedido local | Se anuncia que el pedido todavía no fue enviado y nadie lo recibió | No ejecutado | Pendiente |
| D-07 · Cambio de estado | El cambio sincronizado se anuncia sin buscarlo | No ejecutado; requiere la API local y una sesión ficticia fuera de práctica | Pendiente |
| D-08 · Recursos | Antigüedad y marca de posiblemente desactualizado se entienden al oírlas | No ejecutado | Pendiente |
| D-09 · Contactos | Se puede agregar y borrar un contacto ficticio solo con el lector | No ejecutado | Pendiente |
| D-10 · Modo sencillo | Las mismas pantallas y controles siguen siendo usables | No ejecutado | Pendiente |
| D-11 · Sistema al 200 % y contraste | Texto, foco y acciones siguen siendo visibles y alcanzables | No ejecutado | Pendiente |

En práctica el botón final dice «Guardar en práctica» y el pedido no pasa a enviado. Su botón
de dictado integrado evita servicios externos; D-05 usa el dictado del teclado. Para evaluar el
dictado propio de la app y el anuncio de una actualización real, se requiere el entorno local
con datos ficticios descrito en la guía. No se alteró el aislamiento para aparentar esos resultados.

No se recibieron todavía fallos observados en el teléfono que justifiquen cambiar etiquetas u
orden de la app. No se modificó `emergency_accessibility_test.dart` ni se añadieron pruebas que
presenten una simulación como validación física. Registrar futuras repeticiones con su nuevo commit.
