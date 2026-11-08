# App vecinal (Flutter 3.47.9)

`lib/core/` contiene lo transversal (estados de envío, reintentos, red, modo de la app, tema
accesible, router) y `lib/features/<funcionalidad>/` cada funcionalidad con `domain/`, `data/` y
`presentation/`. `features/solidaridad` es la implementación de referencia: el muro lee de un
repositorio (hoy un doble en memoria; el Lote A lo cambia por PowerSync sin tocar las pantallas).

```bash
flutter pub get && flutter gen-l10n
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
tool\verify.cmd          # Windows: análisis, pruebas y formato con logs en tool\salida\
```

Los textos que ve el vecino están en `lib/l10n/app_es.arb` (claves en inglés, textos en español).
Las carpetas `android/` e `ios/` se generan con `flutter create` la primera vez (lo hace
`tool/verify`).

## Mapas del Lote C

El botón de mapa del muro abre `/mapa`. La región del piloto se puede descargar por Wi-Fi,
cancelar y borrar. La configuración del servidor es `--dart-define=MAP_STYLE_URL=...`
(y `--dart-define=CDN_BASE_URL=...` para las fotos de las reseñas y el directorio de emergencia);
ver `lib/features/mapa/README.md` y `../infra/cdn/README.md` antes de probar en un teléfono.

## Métricas de sincronización

Una vez al día la app envía contadores anónimos de la cola y la conexión a
`POST /v1/telemetria/sincronizacion` (`lib/core/sync/sync_telemetry_reporter.dart`). La versión
que reporta es `--dart-define=APP_VERSION=...` (por defecto la de `pubspec.yaml`). Los campos y su
revisión de privacidad están en `../docs/fase-1/evidencias/sincronizacion.md`.

La integración `maplibre_gl` 0.28 requiere JDK 21, Android API 24+ e iOS 15.5+. El CI verifica
Android e iOS en las solicitudes de revisión. No se necesita habilitar la ubicación del vecino.

## Ingresar con SMS reales (Firebase Authentication)

Por defecto la API envía el código; con `OTP_PROVIDER=fake` lo escribe en su consola. Para recibir
un SMS real, Firebase envía y comprueba el código, y la API solo valida el token que entrega
Firebase (`POST /v1/auth/firebase`). No se sube ningún archivo del proyecto Firebase:

1. En la consola de Firebase, la app Android `pe.shabatshalom.vecinal` debe tener las huellas
   SHA-1 y SHA-256 de la clave con la que firmas. En depuración es la de tu PC
   (`cd android && gradlew signingReport`). Sin ellas, Firebase no envía el SMS.
2. Crea `app/firebase.local.json`; no se sube porque `*.local.json` está en `.gitignore`.
   Los valores están en Configuración del proyecto → Tus apps → Vecinal Android:

   ```json
   {
     "PHONE_AUTH": "firebase",
     "FIREBASE_API_KEY": "<clave de la app Android>",
     "FIREBASE_APP_ID": "1:<número del proyecto>:android:<id>",
     "FIREBASE_SENDER_ID": "<número del proyecto>",
     "FIREBASE_PROJECT_ID": "<ID del proyecto>",
     "API_BASE_URL": "http://127.0.0.1:3000",
     "POWERSYNC_URL": "http://127.0.0.1:8080"
   }
   ```

3. En `backend/.env`: `OTP_PROVIDER=firebase` y `FIREBASE_PROJECT_ID=<ID del proyecto>`.
4. Con el celular por USB, `adb reverse tcp:3000 tcp:3000` y `adb reverse tcp:8080 tcp:8080`
   le dan acceso a la API y a PowerSync de tu PC. Luego:
   `flutter run --dart-define-from-file=firebase.local.json`.

Si la app no viene de Google Play (por ejemplo, instalada por cable), Firebase abre una página de
verificación (reCAPTCHA) en el navegador del celular y vuelve sola a la app. No agregues
`android:taskAffinity=""` a `MainActivity`: con esa línea el resultado no vuelve y no llega el
SMS. Android puede verificar el número sin que el vecino escriba el código (lee el SMS o no lo
necesita); en ese caso la app entra sola. La política de regiones del proyecto solo permite
números de Perú. Si existe `google-services.json` (avisos), pueden omitirse los `FIREBASE_*`:
Firebase lee los archivos nativos.

## Configurar avisos (Lote C)

La compilación normal mantiene `ENABLE_PUSH=false`; no necesita un proyecto Firebase.
Para probar la recepción real, el equipo debe registrar las apps con sus identificadores reales
en Firebase y descargar `android/app/google-services.json` e `ios/Runner/GoogleService-Info.plist`.
Ambos están excluidos de Git, al igual que `lib/firebase_options.dart`.
Puede usarse FlutterFire CLI para obtenerlos; esta implementación inicializa con los archivos
nativos y no importa un archivo Dart privado que impida compilar a los demás lotes.

Android aplica Google Services únicamente cuando existe su JSON. iOS copia el plist al paquete
únicamente si existe. En Xcode, el equipo debe habilitar Push Notifications y Background Modes /
Remote notifications, firmar con su equipo Apple y cargar la clave APNs en Firebase. No inventar
un equipo de firma ni añadir credenciales al repositorio. Limpiar la compilación al retirar o
cambiar los archivos privados para evitar reutilizar una configuración anterior.

Ejecutar con `flutter run --dart-define=ENABLE_PUSH=true` y las URLs del entorno correspondiente.
En el backend usar `NOTIFICATION_DRIVER=fcm` y la cuenta de servicio en el entorno privado.
La recepción dirigida requiere que A conecte su sesión real a `pushCredentialsProvider`; no se
usa la cuenta de demostración para registrar dispositivos. El enlace completo y los requisitos
de cierre de sesión están en `lib/features/avisos/README.md`.

