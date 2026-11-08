# Guía de pruebas en iPhone · A 3.2 y D 4.5

Responsable del recorrido y de las observaciones: `JDiazD33`.
Rama de entrega: `f2-lote-a/parte-3-y-d-4-telefonos`.
Para Android, usar la [guía de protección y TalkBack](telefonos-android.md).

## Preparar e instalar

Conectar por USB un iPhone con credencial local configurada, desbloquearlo y aceptar la confianza
en la Mac. Seleccionar un equipo de desarrollo autorizado en **Signing & Capabilities** de Runner
y activar el modo de desarrollador en el teléfono si Xcode lo pide. Mantener los ajustes locales
de firma fuera del commit. Registrar modelo, versión de iOS, fecha (America/Lima), commit y variante.
Si el equipo de firma no puede registrar el identificador original, usar un identificador único
de desarrollo para la instalación de laboratorio. La versión mínima de Runner y la del paquete
de complementos generado por Flutter deben coincidir en iOS 15.5 para resolver MapLibre.

Desde `app/`, preparar e instalar la variante de práctica:

```bash
flutter pub get
flutter gen-l10n
flutter devices
flutter run --debug -d <id-del-iphone> -t tool/phone_practice.dart
```

Mantener visible «Modo práctica» y usar «Estoy en emergencia» para abrir el tablero. Esta entrada
usa los repositorios de práctica en memoria y funciona sin cuenta, OTP, Firebase ni sincronización.
El pedido queda local y se guarda con «Guardar en práctica».
Iniciar la app desde Flutter o Xcode y dejar el depurador conectado durante el recorrido. Al
intentar abrir la compilación Debug desde el ícono con el depurador desconectado, iOS muestra
el aviso de Flutter sobre el arranque en modo de depuración.

Para A 3.2 y el anuncio de un cambio sincronizado de D 4.5, usar el arranque normal contra una
API de desarrollo con `OTP_PROVIDER=fake` y PowerSync local, con cuentas, evento, pedidos y
ubicaciones ficticios. Usar una red de prueba privada y permitir el acceso a red local si iOS lo
solicita. Sustituir los valores por las direcciones accesibles desde el iPhone:

```bash
flutter run --debug -d <id-del-iphone> \
  --dart-define=API_BASE_URL=<url-api-local> \
  --dart-define=POWERSYNC_URL=<url-powersync-local> \
  --dart-define=ENABLE_PUSH=false --dart-define=ENABLE_PHOTOS=false
```

Para A 3.2, abrir `/emergencia/operacion/<uuid-del-caso>` con el flujo de apertura del caso,
con una cuenta operativa ficticia y una asignación vigente. La vista debe mostrar el caso
autorizado después del desbloqueo. Si dice «Caso no disponible», registrar el bloqueo de la
preparación. Instalar una variante puede reemplazar la otra si usan el mismo identificador.
La [prueba de integración de Emergencias](../../../backend/test/integration/emergencies.int-spec.ts)
muestra la secuencia de habilitaciones, turnos, activación, asignación y permisos que necesita el
caso. Para abrir el detalle sincronizado en el teléfono, iniciar sesión con el OTP falso, que
crea la sesión a la que se vincula el permiso auditado.

## A 3.2 · Selector de apps y primer plano

| Paso | Acción y resultado esperado en iPhone |
|---|---|
| A-01 | Abrir el selector desde el muro o directorio. La miniatura de la app sigue visible como control. |
| A-02 | Abrir el caso ficticio y cancelar el desbloqueo. El caso queda oculto y se puede reintentar. |
| A-05 | Desbloquear el caso y abrir el selector. La miniatura solo muestra la cubierta y el contenido queda ilegible. |
| A-06 | Volver a la app. Primero se ve una pantalla segura. Observar si aparece algún fotograma anterior durante el regreso. |
| A-07 | Volver al muro o directorio y repetir A-01. La cubierta se retira al salir del caso. |
| A-08 | Reabrir el caso protegido y repetir A-05 para comprobar que la cubierta se vuelve a aplicar. |
| A-09 | Volver tras más de cinco minutos de inactividad. Se vuelve a pedir la credencial y se mantiene oculto el contenido previo. |
| A-10 | Repetir el regreso con un caso vencido y el iPhone en modo avión. El detalle caducado queda oculto y se purga de la caché. |

A-03 y A-04 comprueban `FLAG_SECURE` en Android. La prueba de protección de iOS se concentra
en la cubierta del selector y la transición al primer plano. Registrar lo observado en
[modo operativo](modo-operativo.md#teléfonos-reales), sin adjuntar capturas con datos del caso.

## D 4.5 · VoiceOver, texto grande y contraste

1. Activar VoiceOver en Configuración → Accesibilidad → VoiceOver y elegir la voz en español.
   Deslizar un dedo a la derecha o izquierda para recorrer, tocar dos veces para activar el
   elemento enfocado y usar tres dedos para desplazar. Registrar el idioma y la versión de iOS.
2. Ejecutar D-01 a D-11 de la [matriz de accesibilidad](telefonos-android.md#3-d-45-talkback-texto-grande-y-contraste)
   con VoiceOver. Contar las tres activaciones del flujo de ayuda. En D-05 usar el dictado del
   teclado iOS. D-07 requiere una sesión ficticia sincronizada fuera de práctica y un cambio de
   estado desde coordinación mientras el pedido propio sigue abierto.
3. En Configuración → Accesibilidad → Pantalla y tamaño del texto, activar **Aumentar contraste**
   y los tamaños de accesibilidad de **Texto más grande**. Repetir con texto grande y modo sencillo.
   Registrar la posición elegida del ajuste, el tema y si se observaron recortes o controles
   inaccesibles. Si iOS no muestra un porcentaje, registrar su tamaño de accesibilidad y reservar
   el resultado numérico al 200 % para las pruebas que midan esa escala.

Registrar por ID lo que se oyó y lo que se pudo hacer, con resultado «Pasa», «Falla» o «Bloqueado»
en [accesibilidad del modo emergencia](accesibilidad-modo-emergencia.md#teléfonos-reales).
Para los pasos pendientes, dejar «No ejecutado». Evitar nombres, teléfonos, ubicaciones,
descripciones, identificadores del dispositivo y datos de sesión en el registro.

## Preparación comprobada el 8 de noviembre de 2026

Base de código de la rama de teléfonos: `e658974`. Flutter 3.47.9, Dart 3.13.7, Xcode 27.2.
Xcode detectó por USB un iPhone XR con iOS 17.7 y confirmó el emparejamiento.

| Comprobación | Resultado |
|---|---|
| `flutter pub get` y `flutter gen-l10n` desde `app/` | Correctos |
| `xcodebuild` en Debug con `FLUTTER_TARGET=tool/phone_practice.dart` | Compilación firmada correcta. El paquete de complementos generado se ajustó localmente de 15.0 a 15.5 para MapLibre y se firmó con un identificador de laboratorio porque el original no estaba disponible para el equipo local |
| `codesign --verify --deep --strict` y `xcrun devicectl device install app` | Firma válida e instalación USB confirmada en el iPhone XR. El primer intento alcanzó el límite de apps del perfil gratuito. Se retiró un ejecutor de pruebas con autorización y se repitió la instalación |
| `flutter run --debug --use-application-binary` | App iniciada con el depurador conectado. El servicio de Flutter confirmó la entrada de práctica y el muro en el iPhone XR |
| `xcodebuild` en Debug con `FLUTTER_TARGET=lib/main.dart` y `flutter run --use-application-binary` | Variante normal compilada, firmada e iniciada en el iPhone para el ensayo operativo, con direcciones de la API y PowerSync locales |
| Ingreso y apertura del caso en el iPhone XR | `JDiazD33` solicitó y verificó el OTP ficticio. Se confirmó el muro. La ruta del caso se abrió desde el depurador después de autenticar y se confirmó la presencia del bloqueo operativo |
| Corrección `668e015` | Se reprodujo y corrigió la omisión de la suscripción nativa. Tras instalar la corrección, PowerSync entregó el caso al iPhone XR y el responsable vio «En camino» después de desbloquear |
| `flutter test --no-pub test/features/emergencias/phone_practice_test.dart` | 1 aprobada. Abre la práctica sin ingreso y llega al tablero en una prueba de widgets |
| PostgreSQL 18 con PostGIS, API local y PowerSync 1.28.1 | Migraciones y datos de demostración aplicados. PowerSync respondió HTTP 200 en `/probes/readiness` |
| Caso ficticio por API | Evento activo, caso en camino con asignación vigente y permisos auditados de resumen y detalle comprobados con una sesión OTP ficticia |

Los permisos del caso se comprobaron primero por la API en la Mac. La apertura en el iPhone
pasa por el ingreso y el bloqueo de la app. La evidencia del selector y del regreso a primer plano
se registra por separado en [modo operativo](modo-operativo.md#teléfonos-reales).
Las variantes comparten el identificador de laboratorio. En esta Mac, desde `app/`, se conserva
la práctica en `build/ios/phone-practice/Runner.app` y la normal en
`build/ios/Debug-iphoneos/Runner.app`. Se puede retomar cualquiera con
`flutter run --debug -d <id-del-iphone> --use-application-binary=<ruta-app>` y mantener la sesión
de depuración abierta.

## Fuentes

- [Modo de desarrollador en Xcode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device/).
- [Activar VoiceOver y practicar sus gestos](https://support.apple.com/es-es/guide/iphone/iph3e2e415f/ios).
- [Ajustes de pantalla, texto y contraste en iOS](https://support.apple.com/es-es/111773).
