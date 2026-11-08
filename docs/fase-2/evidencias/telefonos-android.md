# Guía de pruebas en Android · A 3.2 y D 4.5

Responsable de las observaciones: `JDiazD33`.
Rama: `f2-lote-a/parte-3-y-d-4-telefonos`, desde `origin/main` en `4fb7761`.
Fecha de preparación: 8 de noviembre de 2026, America/Lima.

Esta guía corresponde a la entrega inicial desde Windows. La continuación en Mac se registra
en la [guía de iPhone](telefonos-ios.md). A 3.2 y D 4.5 exigen ensayos en ambos sistemas.

## 1. Preparar el teléfono y la app

Usar un Android físico con credencial local configurada (PIN o biometría), Flutter 3.47.9 y JDK 21.
La app exige Android API 24 o superior. Registrar modelo, versión de Android, versión de TalkBack,
teclado usado, fecha, commit y opciones de accesibilidad; no registrar el número de serie USB.

1. Activar las opciones de desarrollador y la depuración USB del teléfono. Conectarlo por cable
   y autorizar la computadora en la pantalla del teléfono.
2. Desde `app/`, ejecutar `flutter devices`. Elegir el identificador del **teléfono físico**;
   `windows`, `edge` y un emulador no sirven como evidencia de este encargo.
3. Instalar y ejecutar la compilación de depuración:

   ```bash
   flutter pub get
   flutter gen-l10n
   flutter run --debug -d <id-del-android>
   ```

   El APK se prepara por separado con `flutter build apk --debug` y queda en
   `app/build/app/outputs/flutter-apk/app-debug.apk`, desde la raíz del repositorio.
   Para instalar ese archivo con Android Platform Tools, desde `app/`:

   ```bash
   adb -s <id-del-android> install -r build/app/outputs/flutter-apk/app-debug.apk
   ```

   Si hay más de un dispositivo, conservar `-d`/`-s`; no instalar en otro por omisión.
   El número de serie se usa solo localmente para estos comandos.
4. Para D hay una entrada de **depuración y práctica** que no pide teléfono ni OTP:

   ```bash
   flutter run --debug -d <id-del-android> -t tool/phone_practice.dart
   ```

   Abre `VecinalApp` con los repositorios en memoria existentes, sincronización desconectada y la
   preferencia de práctica activada. No inicia una sesión de la API, Firebase ni reportes externos.
   En el muro, desplazarse hasta «Estoy en emergencia» para abrir el tablero. Mantener visible la
   franja «Modo práctica». Esta entrada rechaza compilaciones que no sean de depuración.
   No abre ni elude la autorización del caso operativo protegido; para A sigue haciendo falta la API local.

   Para preparar su APK: `flutter build apk --debug -t tool/phone_practice.dart`.
   Ambas entradas usan el mismo identificador: instalar una sustituye a la otra. Los APK se conservan
   localmente como `app-practice-debug.apk` y `app-standard-debug.apk` en
   `app/build/app/outputs/flutter-apk/`.

5. La compilación normal abre el ingreso si no hay sesión. La ruta al tutorial requiere sesión
   en el router actual. Para llegar a práctica, usar una cuenta **ficticia de la API local** y
   luego Mi cuenta → Ver tutorial → Modo de práctica. No usar una cuenta personal ni enviar SMS reales.
   La práctica guarda los pedidos y contactos en memoria y no simula acuses. Sin la API local, el
   ingreso normal no puede enviar el código: usar la entrada de práctica, sin ingresar un número personal.

### API local para ingreso y modo operativo

Usar la instalación local ya configurada según [backend/README.md](../../../backend/README.md) e
[infra/README.md](../../../infra/README.md), con datos de demostración y proveedor OTP falso.
No usar Firebase/SMS reales. No sustituir la configuración privada del equipo ni copiar tokens a
este documento. Comprobar `NODE_ENV` de desarrollo y `OTP_PROVIDER=fake` antes de iniciar sesión.

Con la API y PowerSync locales ejecutándose en la computadora, el teléfono por USB puede acceder
a ellos sin publicar servicios ni abrir puertos en la red:

```bash
adb -s <id-del-android> reverse tcp:3000 tcp:3000
adb -s <id-del-android> reverse tcp:8080 tcp:8080
flutter run --debug -d <id-del-android> --dart-define=API_BASE_URL=http://127.0.0.1:3000 --dart-define=POWERSYNC_URL=http://127.0.0.1:8080 --dart-define=ENABLE_PUSH=false --dart-define=ENABLE_PHOTOS=false
```

El proveedor OTP falso entrega el código en el entorno local; no asumir un código fijo.
Para la prueba protegida, el responsable debe disponer de una cuenta operativa ficticia, un caso
ficticio asignado, permiso auditado vigente y acceso a `/emergencia/operacion/<uuid-del-caso>`
mediante el flujo de apertura del caso. En modo práctica esa pantalla se rechaza por diseño.
Si no se puede abrir el caso, registrar **Bloqueado por preparación del entorno**, no «Pasa».
Un mensaje de caso no disponible no demuestra la protección de una pantalla con datos.

## 2. A 3.2: capturas, grabación y selector de apps

Mantener solo datos ficticios en el entorno. Las capturas o grabaciones guardadas como evidencia
no pueden contener nombres, teléfonos, ubicaciones ni descripciones, aunque sean de prueba.
Si una comprobación revela contenido, registrar el fallo **en texto**, sin adjuntar ni subir esa imagen.
Para una pantalla normal con filas o datos, también es preferible describir la captura en texto.

| ID | Acción de JDiazD33 | Resultado esperado en Android |
|---|---|---|
| A-01 | Abrir muro o directorio normal y hacer una captura del sistema | El sistema permite capturar. No guardar evidencia visual si contiene datos |
| A-02 | Abrir la pantalla operativa del caso ficticio y cancelar primero el desbloqueo | El contenido del caso no aparece; se puede reintentar |
| A-03 | Desbloquear el caso con la credencial del teléfono y hacer una captura | El sistema rechaza la captura o entrega una imagen vacía/negra; no aparece el caso |
| A-04 | Con el grabador del sistema activo desde una pantalla normal, entrar a la protegida; repetir iniciando la grabación desde la protegida | Ningún fotograma grabado muestra el contenido protegido; un rechazo de grabación también sirve. Sin grabador disponible, dejar el paso bloqueado |
| A-05 | Desde el caso desbloqueado abrir el selector de apps | La miniatura no permite leer el caso. En Android puede ser una superficie vacía/negra; no se exige el difuminado de iOS |
| A-06 | Volver desde el selector antes del límite de inactividad | Primero se ve una vista segura/bloqueada; no hay destello del caso anterior. El caso vuelve solo tras la revisión y el desbloqueo necesarios |
| A-07 | Volver atrás a muro/directorio y tomar otra captura | La protección se retira y la captura normal funciona otra vez |
| A-08 | Volver a abrir la pantalla protegida y repetir captura y selector | La protección se aplica otra vez; no queda desactivada por la navegación anterior |
| A-09 | Dejar el caso sin actividad por más de cinco minutos y volver a primer plano | El caso queda bloqueado y exige la credencial; no aparece el contenido anterior antes de autorizar |

Observar la pantalla física durante A-06 y A-09: una grabación protegida negra no permite concluir
si hubo un destello visible en el panel. No intentar eludir `FLAG_SECURE` para obtener evidencia.
El comportamiento del fabricante se registra literalmente y se evalúa por ausencia de contenido.

Registrar cada resultado, con esos IDs, en
[modo-operativo.md, Teléfonos reales](modo-operativo.md#teléfonos-reales).

## 3. D 4.5: TalkBack, texto grande y contraste

### Configuración y gestos

En Ajustes → Accesibilidad, activar TalkBack y elegir español. En Tamaño de pantalla y texto,
llevar el tamaño de fuente al 200 % cuando la versión lo permita y activar el contraste de texto
del sistema. En Android 16 o superior puede llamarse **Texto con contorno**; en versiones anteriores,
**Texto de alto contraste**. Anotar el nombre exacto y el valor disponible. Si no se alcanza el
200 %, registrar el tamaño máximo y dejar ese requisito pendiente; la ampliación de pantalla no
es equivalente a aumentar el tamaño de fuente.

Con TalkBack: deslizar a la derecha/izquierda recorre elementos, doble toque activa el elemento
enfocado y dos dedos desplazan el contenido. Contar **tres activaciones de botones** en el flujo
de ayuda, no tres contactos físicos: el lector necesita gestos adicionales de exploración.
Probar primero con modo sencillo apagado y repetir los recorridos principales con él encendido.

| ID | Acción de JDiazD33 | Resultado esperado |
|---|---|---|
| D-01 | Abrir el tablero en práctica y recorrer desde el inicio sin tocar posiciones concretas | Se anuncia primero el título; el foco avanza en un orden comprensible y siempre se identifica |
| D-02 | Recorrer «Necesito ayuda», «Puedo ayudar», «Recursos» y el directorio | Cada control anuncia un nombre y su función de botón; se puede activar con el lector |
| D-03 | Seguir hasta las alternativas oficiales | Se entiende el recordatorio «Si hay riesgo para la vida, llama al 116, 105 o 106». No activar llamadas |
| D-04 | Activación 1: «Necesito ayuda»; activación 2: tipo de necesidad; completar descripción y ubicación ficticias; activación 3: guardar | Cada pantalla anuncia su contexto y los campos se pueden editar. En práctica el botón dice «Guardar en práctica», no «Enviar» |
| D-05 | Completar un campo mediante el dictado del teclado del sistema con TalkBack | El dictado permite completar y corregir texto y volver al formulario. Registrar teclado, disponibilidad y resultado; no confundirlo con el botón de dictado de la app |
| D-06 | Tras guardar, recorrer el pedido propio | Se anuncia el estado local y «Tu pedido todavía no fue enviado. Nadie lo ha recibido.»; las alternativas siguen accesibles |
| D-07 | En una segunda sesión de la API local con datos ficticios, actualizar desde coordinación el estado de un pedido mientras esta pantalla sigue abierta y sincronizada | El cambio de estado se anuncia sin buscarlo ni reabrir la pantalla. Registrar ambos estados y lo oído, sin datos del caso |
| D-08 | Abrir Recursos y recorrer los ejemplos precargados de práctica | Se oyen la antigüedad «reportado hace…» y la marca de posiblemente desactualizado cuando corresponde |
| D-09 | En Contactos, agregar un contacto ficticio y borrarlo solo con el lector | Se identifican campos, validaciones, guardar y borrar; el contacto desaparece. No abrir el compositor ni llamar |
| D-10 | Activar Modo sencillo desde Mi cuenta y repetir tablero, formulario, pedido, recursos y contactos | Todos los controles siguen alcanzables; no hay texto imprescindible recortado, superpuesto o inaccesible al desplazarse |
| D-11 | Repetir navegación con 200 % y contraste del sistema activos; si es posible revisar temas claro y oscuro | El foco, los textos y las acciones siguen siendo distinguibles y operables; registrar los ajustes y temas realmente probados |

### Límites de práctica que no se deben falsear

- El botón de dictado propio de la app no abre el servicio externo en práctica: muestra el aviso
  correspondiente. D-05 prueba el **teclado del sistema**. Probar el botón propio requiere una
  cuenta ficticia de la API local fuera de práctica, permisos de micrófono y el reconocimiento
  disponible en el teléfono. Registrar ese ensayo por separado, sin cambiar el aislamiento.
- Un pedido de práctica permanece local: no convertirlo a enviado para simular D-07. Ese paso
  necesita una sesión ficticia de la API local y sincronización real del entorno de prueba.
- Sin sesión local que permita entrar al tutorial, no afirmar que se recorrió práctica; registrar
  el bloqueo del entorno. Ninguna parte de esta guía habilita un acceso operativo sin autorización.

Registrar cada resultado en
[accesibilidad-modo-emergencia.md, Teléfonos reales](accesibilidad-modo-emergencia.md#teléfonos-reales).
Si un fallo real corresponde a una etiqueta u orden de la app, registrar cómo reproducirlo,
corregirlo con su prueba en `emergency_accessibility_test.dart` y repetir ese paso en el mismo teléfono.

## 4. Devolver la observación

Para cada ejecución, devolver en texto:

```text
Responsable: JDiazD33
Modelo Android y versión:
Versión de TalkBack y teclado:
Fecha/hora (America/Lima):
Commit compilado:
SHA-256 del APK (si se instaló el archivo):
Tamaño de fuente y opción de contraste del sistema:
Modo sencillo / tema / práctica o API local:
A-01: observado ...; Pasa / Falla / Bloqueado
... (una línea por cada ID)
D-11: observado ...; Pasa / Falla / Bloqueado
Hallazgos y repetición:
```

No incluir contenido de casos ni contactos, identificadores de sesión ni tokens. Si se modifica
la app, registrar el nuevo commit y repetir los pasos afectados. Mientras falte una observación,
esa celda dice «No ejecutado», nunca «Pasa». La preparación local no cierra A 3.2 ni D 4.5.

## Fuentes para preparar los pasos

- [Android Developers: FLAG_SECURE](https://developer.android.com/security/fraud-prevention/activities):
  protección de capturas y superficies no seguras; el resultado debe verificarse en el dispositivo.
- [Ayuda de Android: tamaño y contraste del texto](https://support.google.com/accessibility/android/answer/11183305?hl=es):
  ajuste de fuente y opciones de contraste según la versión.
- [Ayuda de Android: accesibilidad](https://support.google.com/accessibility/android/answer/6006564?hl=es):
  TalkBack y configuración del sistema.
