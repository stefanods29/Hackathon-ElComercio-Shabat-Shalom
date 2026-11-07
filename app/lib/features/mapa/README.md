# Mapa del distrito · Lote C, Parte 2

Pantalla `/mapa`, accesible desde el botón de mapa del muro. Usa el estilo y las teselas XYZ
propios preparados en C1. No necesita la API, PowerSync, Firebase ni entregas de otros lotes.
El área es **Lince y alrededores (demostración)**; no representa límites administrativos oficiales.

## Estructura y responsabilidades

```text
mapa/
├── domain/
│   ├── offline_region.dart          # definición validada, estados y errores tipados
│   ├── download_policy.dart         # política Wi-Fi y puerto de conectividad
│   └── map_region_repository.dart   # interfaz del almacenamiento de la zona seleccionada
├── data/
│   ├── offline_map_store.dart       # frontera pequeña para probar sin canales nativos
│   ├── maplibre_offline_map_store.dart  # traducción de la API de MapLibre 0.28
│   ├── maplibre_region_repository.dart  # persistencia, progreso y cancelación segura
│   ├── connectivity_map_monitor.dart   # adaptación de connectivity_plus
│   └── providers.dart               # composición e implementaciones reemplazables
└── presentation/
    ├── map_download_controller.dart # acciones y estado de la pantalla
    ├── map_page.dart                # interfaz, confirmación de borrado y accesibilidad
    └── map_view.dart                # vista nativa reemplazable en pruebas
```

El dominio es Dart puro. La pantalla no conoce identificadores nativos, canales de plataforma,
HTTP ni bases de datos. `MapBounds` está en `core/geo/` para que la configuración transversal
no dependa de una funcionalidad. `AppEnvironment` aporta estilo y límites del piloto.

El repositorio se configura para una zona seleccionada: `download()` usa esa definición
validada, sin volver a recibir una configuración distinta desde la pantalla. El proveedor puede
reemplazarse al incorporar más zonas. Las pantallas y puertos de los otros lotes se conservan.

## Comportamiento

- Descarga zoom **10–15**, con progreso y bytes reportados por MapLibre. MB usa 1 000 000 bytes.
- «Mapa listo» exige confirmación nativa; un porcentaje del 100 % no basta.
- Al abrir o volver a la app se comprueba el estado de la región guardada. Una descarga parcial
  nunca se muestra como lista. Si iOS elimina la caché, se deberá descargar otra vez.
- Wi-Fi por defecto. El permiso para datos móviles es explícito y no se persiste entre
  reinicios del proceso. El tipo de conexión no garantiza acceso a internet.
- Si se pierde la conexión permitida durante una descarga, se cancela y elimina la región
  parcial. Se vuelve a descargar cuando el vecino lo decide. El observador continúa mientras
  viva el proveedor, aunque la pantalla se haya cerrado; al volver a primer plano se comprueba
  la conexión otra vez. El sistema operativo puede retrasar eventos en segundo plano, por lo
  que esta política no promete un corte instantáneo de cada solicitud nativa.
- Cancelar espera el identificador nativo si todavía se está creando y descarta eventos tardíos.
- Borrar pide confirmación y elimina solamente regiones del piloto gestionadas por esta
  funcionalidad, también de configuraciones anteriores. No borra mapas ajenos ni resetea toda
  la base compartida de MapLibre. La caché ambiental del visor puede conservar recursos reutilizables.
- La atribución está fuera del área desplazable y escala con el texto del sistema. Los botones
  tienen al menos 48 dp. Los mensajes viven en `app_es.arb`, con errores en lenguaje simple.

## Requisitos comprobados en el paquete instalado

`maplibre_gl` **0.28.0**: Android **API 24+**, JDK **21**, NDK **28.2.13676358** e iOS **15.5+**.
Los mínimos se tomaron del `build.gradle` y `Package.swift` publicados, no de ejemplos antiguos.
La versión exacta resuelta queda en `pubspec.lock`. El proyecto iOS usa Swift Package Manager;
no se agrega un Podfile que la plantilla no utiliza.

Android permite HTTP únicamente en el manifiesto **debug**. Los builds release deben usar
fuentes HTTPS. iOS declara el uso de la red local y permite esa conexión con
`NSAllowsLocalNetworking`, manteniendo ATS para los dominios públicos. No se habilita
`NSAllowsArbitraryLoads`. No se pide acceso a la ubicación del vecino.

## Ejecutar

Primero generar y servir los mapas siguiendo `infra/cdn/README.md`. En `app/`:

```sh
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter run --dart-define=MAP_STYLE_URL=http://10.0.2.2:8090/estilos/vecinal.json
```

`10.0.2.2` funciona desde el emulador Android. Para un teléfono real, usar una dirección
alcanzable por ese teléfono y regenerar primero el estilo de C1 con `MAP_PUBLIC_URL` apuntando
al mismo servidor: cambiar solo `MAP_STYLE_URL` no cambia las URLs internas de las teselas.
En una distribución release, usar HTTPS para el estilo y todos sus recursos.

## Pruebas y límites de la evidencia

`test/features/mapa/` prueba política y clasificación de conexión, restauración de regiones,
configuraciones diferentes, cancelación antes de recibir el ID nativo, callbacks tardíos,
reintentos, borrado acotado, navegación, progreso, confirmación y accesibilidad al 200 %.
La vista y el almacén nativos se reemplazan por dobles durante esas pruebas.

La compilación del APK verifica la integración nativa. Ni las pruebas con dobles ni compilar
demuestran que una región se navegue en modo avión. La prueba de campo, tamaño real y descarga
por Wi-Fi en Android de gama baja, así como la verificación en iPhone, están pendientes y se
registran en `docs/fase-0/evidencias/mapas.md`.
