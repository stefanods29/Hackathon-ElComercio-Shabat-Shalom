# Fuentes y atribución del mapa

**© OpenStreetMap contributors** · [Información de derechos de OSM](https://www.openstreetmap.org/copyright).
El mapa de demostración contiene datos públicos, no ubicaciones personales del proyecto.

| Componente | Fuente | Licencia / aviso conservado |
|---|---|---|
| Teselas Protomaps (OSM y Natural Earth) | [Distribución de mapas](https://docs.protomaps.com/basemaps/downloads) | Obra producida bajo ODbL; `protomaps-datos.txt` |
| Cobertura terrestre (`landcover`) | [ESA WorldCover](https://esa-worldcover.org/en/data-access), vía el build Protomaps | CC BY 4.0; atribución y enlace de licencia en el mapa, aviso en `protomaps-datos.txt` |
| Estilo Protomaps | [basemaps](https://github.com/protomaps/basemaps) | BSD-3-Clause; `protomaps-BSD.txt` |
| Fuentes Noto | [basemaps-assets](https://github.com/protomaps/basemaps-assets/tree/028c18f713baecad011301ff7a69acc39bcc2ae7/fonts) | SIL OFL; `/fuentes/OFL.txt`, copiado al generar |
| Iconos Mapzen | [tangrams/icons](https://github.com/tangrams/icons) | MIT; `iconos-MIT.txt` |
| Visor MapLibre GL JS | [MapLibre](https://github.com/maplibre/maplibre-gl-js) | BSD-3-Clause; `/vendor/LICENSE.txt`, copiado al generar |

Las versiones de paquetes están en `package-lock.json` y la revisión de recursos y origen de
las teselas en `district.config.json`. La licencia de los datos no cambia por alojar el recorte.
