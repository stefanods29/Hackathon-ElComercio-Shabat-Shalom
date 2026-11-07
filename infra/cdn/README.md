# Mapas del Lote C · Parte 1

Generación reproducible del recorte de **Lince y alrededores (demostración)**. El rectángulo
incluye la zona sembrada en el backend; **no es un límite administrativo oficial**.
Esta parte funciona sin API, PowerSync, Firebase ni entregas de otros lotes.

## Decisión

El archivo propio `distrito.pmtiles` se sirve con Range. El mismo archivo se expone como teselas
XYZ para que MapLibre Native pueda descargar una región sin conexión en la Parte 2.
El estilo claro prioriza etiquetas en español y sirve fuentes e iconos desde nuestra CDN.
Ver [ADR 0008](../../docs/adr/0008-fuente-de-teselas.md), pendiente de aprobación del equipo.

## Requisitos

- Node y npm (el proyecto fija Node 26; estas herramientas también admiten Node 22).
- [PMTiles CLI **1.31.2**](https://github.com/protomaps/go-pmtiles/releases/tag/v1.31.2):
  descomprimir el binario oficial en `infra/cdn/.tools/`, instalarlo en el PATH o definir
  `PMTILES_BIN` con su ruta absoluta. No se instala nada globalmente con nuestros scripts.
- Docker Compose para servir los mapas; no hace falta iniciar los servicios de otros lotes.

## Generar (desde `infra/cdn/`)

```powershell
npm ci
npm run build
npm test
npm run verify
npm run format:check
```

`build` genera el estilo, copia las fuentes/sprites y el visor a partir de versiones fijas, y
extrae solo el recorte del archivo planetario. No descarga el mapa completo del mundo.
Imprime el tamaño final y guarda origen, configuración y SHA-256 en `distrito.manifest.json`.

Para regenerar únicamente el mapa también existen los dos accesos equivalentes:

```powershell
# Windows
.\scripts\build-district-tiles.ps1
```

```sh
# Linux/macOS
sh scripts/build-district-tiles.sh
```

La configuración compartida está en `district.config.json`: coordenadas oeste/sur/este/norte,
centro, zoom, URL fechada del mapa, versión del esquema y revisión de los recursos.
El archivo conserva zoom 0–15 para permitir una vista general. La descarga móvil de zoom 10–15
se implementará en C2; generar el archivo no demuestra todavía funcionamiento offline en móvil.
Si los servicios ya estaban leyendo un mapa anterior, detenerlos antes de regenerar y volver
a iniciarlos después, para que el servidor de teselas descarte su caché del archivo anterior.

### Dirección pública

Por defecto el estilo usa `http://10.0.2.2:8090`, para el emulador Android. Para un teléfono
real o una CDN, regenerar con el origen que ese dispositivo alcanza:

```powershell
$env:MAP_PUBLIC_URL = 'http://192.168.1.10:8090'
npm run build:style
Remove-Item Env:MAP_PUBLIC_URL
```

En Linux: `MAP_PUBLIC_URL=https://mapas.example.org npm run build:style`.
Los cambios de dirección son locales: restaurar el estilo predeterminado con
`npm run build:style` antes de entregar. El visor web adapta esas direcciones al origen desde
el que se abre, conservando las plantillas de MapLibre.

## Servir y comprobar

Desde `infra/`:

```sh
docker compose up -d cdn
```

Solo inicia `cdn` y su dependencia `teselas`. Abrir
[el visor local](http://localhost:8090/visor.html).
Desde `infra/cdn/`:

```sh
npm run verify -- --url http://localhost:8090
```

Comprueba PMTiles v3, SHA-256, estilo válido, recursos locales, respuesta **206** a
`Range: bytes=0-1023` y una tesela XYZ del centro de la zona. La atribución debe permanecer
visible. En Windows, la prueba manual equivalente usa `curl.exe`, no el alias de PowerShell:

```powershell
curl.exe -I -H 'Range: bytes=0-1023' http://localhost:8090/distrito.pmtiles
```

## Licencias y archivos generados

La información pública está en `publico/licencias/`. Las fuentes incluyen `fuentes/OFL.txt`;
el visor conserva `vendor/LICENSE.txt`. No se descargan teselas de `tile.openstreetmap.org`.

No se suben a Git el PMTiles, su manifiesto, los recursos binarios generados, las dependencias
ni `.cache/` y `.tools/`. Sí se versionan la configuración, los scripts, el estilo y el visor.

Protomaps retiene los builds de la última semana y el último de cada versión de parche. La URL
fechada puede caducar: el script falla de forma visible, sin cambiar a otro mapa silenciosamente.
Para actualizarla, seleccionar un build del catálogo oficial, actualizar conjuntamente URL,
versión y BLAKE3 en `district.config.json`, regenerar y volver a verificar. El BLAKE3 es el hash
publicado del planeta, no una comprobación local de sus ~139 GB. El SHA-256 local corresponde
al recorte efectivamente descargado. Conservar el recorte y su manifiesto en el almacenamiento
del equipo cuando se elija; esta entrega no publica archivos en servicios externos.

## Validación automática

El flujo `Mapas del lote C` valida estilo, recursos, cinco pruebas y formato en cada PR.
`npm run verify -- --assets-only` comprueba únicamente los recursos, sin afirmar que exista un
mapa. Al ejecutarlo manualmente en GitHub también genera el recorte real y prueba Docker,
Range y XYZ. Esa ejecución requiere que la URL fechada siga disponible.
