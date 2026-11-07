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
