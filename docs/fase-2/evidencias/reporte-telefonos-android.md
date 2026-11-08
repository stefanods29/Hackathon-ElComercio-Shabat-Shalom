# Reporte de preparación Android · pantallas protegidas y lector

Fecha: 8 de noviembre de 2026, America/Lima.
Responsable de ejecutar las pruebas en teléfono y comunicar sus observaciones: `JDiazD33`.
Rama de entrega: `f2-lote-a/parte-3-y-d-4-telefonos`.
Base de la app: `4fb7761a52d2762911dbfb02ea5b7c9e25781d26`, de `origin/main` actualizado.
Esta rama agrega una entrada de depuración para práctica y su prueba, además de documentación.

## Alcance y resultado

Se prepararon la guía de instalación Android y los protocolos de A 3.2 y D 4.5, con un resultado
esperado para cada paso y tablas para registrar lo que observe el responsable. El alcance se
limitó a Android por indicación expresa durante la entrega.

**iPhone y VoiceOver no se ejecutaron por no disponer de una Mac con Xcode ni de las herramientas
de firma de desarrollo de iOS.** No se declara una compilación iOS, una instalación ni una prueba
en iPhone. Tampoco se atribuye a un teléfono el resultado de las pruebas automáticas de escritorio.

Se conectó el **POCO X6 Pro** indicado por el usuario. ADB confirmó fabricante Xiaomi, modelo
`2311DRK48G`, **Android 16, API 36** y TalkBack `17.1.0.1003738110`. La conexión pasó inicialmente
por «no autorizado» y la primera instalación por «INSTALL_FAILED_USER_RESTRICTED»; el usuario
autorizó la conexión y la instalación posterior fue correcta. No se publican números de serie USB.

El usuario observó que el ingreso normal no podía enviar el código. Se comprobó que no hay una
API local disponible ni configuración `backend/.env` en este checkout. Para recorrer D sin cuenta
real, se preparó una entrada aislada que inicia la práctica existente sin teléfono ni OTP.
Los recorridos de TalkBack y las capturas del contenido protegido todavía requieren observación
y resultado por paso. No se tomaron capturas ni grabaciones de evidencia.

## Trabajo realizado

1. Se leyeron la integración de la fase, el alcance de A y D, sus tareas y las evidencias previas.
   No se encontró `reglas-de-trabajo.md` ni un `AGENTS.md` aplicable en el checkout o sus directorios
   superiores comprobados. Se conservaron las decisiones de integración y los responsables existentes.
2. Se revisaron el canal de protección, `OperationalGate`, la pantalla del caso y el código
   Android/iOS para preparar pasos acordes al comportamiento implementado, sin modificarlo.
3. Se comprobó el entorno y la detección de dispositivos. Se preparó la compilación Android de
   depuración y se ejecutaron las verificaciones indicadas en la sección siguiente.
4. Se prepararon nueve pasos de protección y once pasos de accesibilidad, con instrucciones de
   instalación por USB, datos ficticios, controles de captura normal/protegida, grabación, selector,
   primer plano, salida de la protección, inactividad, TalkBack, fuente al 200 %, contraste y modo sencillo.
5. Se documentaron los límites reales de práctica: el pedido queda local, el botón final dice
   «Guardar en práctica», su dictado integrado no abre servicios externos y la vista operativa
   exige una sesión ficticia autorizada de la API local fuera de práctica. Se distingue el dictado
   del teclado del dictado de la app y el anuncio sincronizado de estados de la lectura del estado local.
6. Se añadieron las secciones «Teléfonos reales» solicitadas, con esperado/observado/resultado,
   dejando «No ejecutado» donde no existe observación. Se enlazaron las tareas sin marcarlas como hechas.
7. Se agregó `app/tool/phone_practice.dart`: abre las pantallas existentes con práctica activa,
   repositorios en memoria y sincronización desconectada, sin abrir la API ni Firebase. Solo
   funciona en depuración; no cambia el ingreso normal, el código nativo ni la autorización del
   caso operativo. Su prueba verifica que abre sin formulario de ingreso y llega al tablero real.

## Verificación local

Los pasos equivalentes a `app/tool/verify.sh` se ejecutan directamente con Flutter y Dart en
Windows. Los registros locales quedan en `app/tool/salida/`, fuera del control de versiones.

| Comando | Resultado |
|---|---|
| `flutter doctor -v` | Flutter 3.47.9, Dart 3.13.7 y SDK Android 37; advierte que faltan cmdline-tools y que desconoce el estado de licencias. No se aceptaron licencias ni se cambiaron archivos nativos |
| `flutter devices` y ADB | Al inicio solo Windows/Edge; después se autorizó el POCO y se consultaron modelo, Android y TalkBack |
| `flutter pub get` | Correcto |
| `flutter gen-l10n` | Correcto |
| `flutter build apk --debug` | Correcto; APK normal generado e instalado por USB |
| `flutter analyze` | Sin observaciones, incluida la entrada de práctica |
| `flutter test --reporter expanded` | 279 aprobadas, 7 omitidas, 0 fallos en esta rama; antes de agregar la entrada: 278 aprobadas, 7 omitidas |
| `dart format --output=none --set-exit-if-changed lib test tool/phone_practice.dart` | 225 archivos, sin cambios |
| `flutter build apk --debug -t tool/phone_practice.dart` | Correcto; APK de práctica generado, instalado por USB y abierto en el POCO |
| `npx --yes @fission-ai/openspec@1.16.1 validate --all --strict --no-interactive` | 30 elementos válidos, 0 fallos; misma versión usada por la CI |

Las siete pruebas omitidas son seis comparaciones de imágenes reservadas a macOS y una prueba
preexistente que requiere el servicio en vivo. Ninguna omisión equivale a una prueba física aprobada.

Se reinició la compilación con un máximo de dos trabajadores de Gradle y heap de 2 GiB, solo
mediante variables de la ejecución local, por la memoria disponible en el equipo. No se cambiaron
archivos de Android. El build emite advertencias existentes de Kotlin en dependencias y de versión
XML del SDK; la compilación normal terminó con código 0.

El APK anterior que ya existía en el equipo no se cuenta como compilación de esta entrega.
El APK normal nuevo se generó el 8 de noviembre a las 11:37 (America/Lima): 246 998 841 bytes,
SHA-256 `0e4798c4ef2b26098a60ede5472c4cc696af55e9f0538f9ee702cc622899e8c5`.
Se conserva en `app/build/app/outputs/flutter-apk/app-standard-debug.apk`.
El APK de práctica se generó el 8 de noviembre a las 11:49 (America/Lima): 246 106 132 bytes,
SHA-256 `f62e49d1e4c29877eb57018867f1fc2789f6e36cf3e19e709edf9b06eba21935`.
Se conserva en `app/build/app/outputs/flutter-apk/app-practice-debug.apk`. ADB confirmó `Success`
al instalarlo y `am start` abrió la actividad de la app. Falta registrar la observación del usuario
sobre el arranque visible y los recorridos con TalkBack; no se deduce de esos comandos.

La consulta inicial del teléfono devolvió escala de fuente `1.1` (110 %) y ningún valor definido
para `high_text_contrast_enabled`. No se modificaron esos ajustes por ADB ni se da por probado
el 200 %, el contorno de texto de Android 16 o TalkBack activo por el solo hecho de estar instalado.

## Archivos de la entrega

| Archivo | Para qué se cambió |
|---|---|
| [phone_practice.dart](../../../app/tool/phone_practice.dart) | Entrada exclusiva de depuración, sin OTP ni cuenta real, para recorrer la práctica existente |
| [phone_practice_test.dart](../../../app/test/features/emergencias/phone_practice_test.dart) | Comprueba arranque en práctica y acceso al tablero sin ingreso |
| [telefonos-android.md](telefonos-android.md) | Guía de instalación, preparación del entorno ficticio, configuración del lector y pasos A-01 a A-09 y D-01 a D-11 |
| [modo-operativo.md](modo-operativo.md#teléfonos-reales) | Sección nueva con identificación del teléfono y matriz de esperado/observado/resultado de protección |
| [accesibilidad-modo-emergencia.md](accesibilidad-modo-emergencia.md#teléfonos-reales) | Sección nueva con configuración de TalkBack y matriz de accesibilidad física |
| [Tareas de A](../../../openspec/changes/fase-2-lote-a-pedidos-offline-y-modo-operativo/tasks.md) | Motivo explícito por el que A 3.2 sigue abierta y enlaces a la preparación |
| [Tareas de D](../../../openspec/changes/fase-2-lote-d-tablero-de-emergencia/tasks.md) | Motivo explícito por el que D 4.5 sigue abierta y enlaces a la preparación |
| Este reporte | Resultado del trabajo, verificaciones, alcance y pendientes |

No se cambiaron el código nativo, el ingreso de producción, los textos de la app ni la configuración
de firma. El bloqueo del OTP corresponde al entorno local ausente y se resolvió para el ensayo
mediante la entrada de práctica, sin fingir un servidor ni un acuse. Los binarios y los registros
locales de compilación no se incluyen en Git.

## Tareas y siguiente ejecución

| Tarea | Estado | Motivo |
|---|---|---|
| A 3.2 | Abierta | El Android está conectado, pero faltan API local, cuenta operativa ficticia, caso autorizado y observaciones de protección. iPhone pendiente por falta de Mac/Xcode/firma |
| D 4.5 | Abierta | Faltan el recorrido con TalkBack, el contraste y texto grande reales, el dictado y el anuncio de estados. VoiceOver pendiente por falta de Mac/Xcode/firma |

No se marcó ninguna tarea nueva `[x]`. Los veinte resultados paso a paso están en las dos secciones
«Teléfonos reales»; todos están pendientes de la ejecución física. Las demás tareas conservan su estado.

Para continuar, abrir la variante de práctica, seguir la [guía](telefonos-android.md) y devolver
configuración del lector y del sistema, fecha, commit y lo observado para cada ID.
Solo entonces se registrarán pasos aprobados o fallidos y, si corresponde, se corregirá un fallo
con su prueba automática y su repetición física. Aun si Android pasa, no cerrar A 3.2 o D 4.5
hasta completar también el sistema iOS que exigen esas tareas.
