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
cancelar y borrar. La configuración del servidor es `--dart-define=MAP_STYLE_URL=...`;
ver `lib/features/mapa/README.md` y `../infra/cdn/README.md` antes de probar en un teléfono.

La integración `maplibre_gl` 0.28 requiere JDK 21, Android API 24+ e iOS 15.5+. El CI verifica
Android e iOS en las solicitudes de revisión. No se necesita habilitar la ubicación del vecino.

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

## Fotos y compartir (Fase 1 C)

Activar la galería con `--dart-define=ENABLE_PHOTOS=true`; sin sesión real conserva borradores
privados en el teléfono. La cola, sus componentes y la integración con A/B/D están descritos en
`lib/features/media/README.md`. Configuración del servidor local: `../infra/media/README.md`.

Compartir usa el selector del teléfono, incluido WhatsApp si está disponible. Requiere un origen
real en `PUBLIC_APP_URL` y una publicación confirmada. Consultar `lib/features/compartir/README.md`.
`SENTRY_DSN` es opcional; sin él no se inicializa Sentry. El informe de implementación y sus
comprobaciones están en `../docs/fase-1/evidencias/lote-c.md`.

