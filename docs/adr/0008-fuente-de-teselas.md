# 0008 · PMTiles propio y salida XYZ para el mapa offline

**Estado:** aprobado el 7 de noviembre de 2026, al cerrar la Fase 0 (PR de cierre).
**Dueño:** Lote C · Parte 1. **Consulta de fuentes:** 7 de noviembre de 2026.
**Alcance:** sección 3.4 de la arquitectura y `mapas/region-offline` de OpenSpec.

## Contexto

La app necesita un mapa descargable sin depender de los otros lotes. La infraestructura ya
contiene nginx con soporte de Range, pero no un archivo de mapas ni un estilo utilizable.
El piloto sembrado está en Lince; el recorte de demostración usa
`[-77.07, -12.10, -77.01, -12.06]`, que incluye esa zona y sus alrededores. No es un polígono
administrativo oficial.

## Opciones

1. **PMTiles propio a partir de un recorte del build Protomaps.** Generación rápida, sin cuenta
   ni claves y con fuente fechada. El servicio de origen se usa solo para generar el recorte;
   los clientes consultan nuestros archivos.
2. **Generación completa con Planetiler y datos OSM.** Mayor independencia del catálogo de
   builds, pero necesita más descarga, memoria y herramientas. Se puede incorporar posteriormente.
3. **Proveedor de teselas.** Requeriría elegir proveedor, comprobar sus términos de descarga
   offline y acordar presupuesto. No se necesita para esta prueba técnica.

Los servidores públicos de teselas de OSM quedan excluidos conforme a la arquitectura y la
[política oficial](https://operations.osmfoundation.org/policies/tiles/).

## Decisión propuesta

- Generar `distrito.pmtiles` con PMTiles CLI **1.31.2**, a partir del build fechado
  `20261107.pmtiles`, esquema **4.15.2**. Coordenadas, versiones y hash publicado del origen
  quedan en `infra/cdn/district.config.json`.
- Mantener zoom 0–15 en el archivo, para permitir una vista general. C2 descargará una región
  de zoom 10–15 mediante la API offline de MapLibre.
- Usar `@protomaps/basemaps` **5.7.2**, sabor claro y prioridad de nombres en español.
  Fuentes e iconos proceden de una revisión fija de `basemaps-assets`; se sirven localmente.
- Servir el PMTiles directamente desde nginx con Range y ofrecer **XYZ** en
  `/teselas/{z}/{x}/{y}.mvt`, mediante `protomaps/go-pmtiles:v1.31.2`, leyendo el mismo archivo.
- Generar URLs absolutas para MapLibre Native, configurables con `MAP_PUBLIC_URL`.
  El visor web adapta el origen conservando las plantillas de fuentes y teselas.

### Compatibilidad que motiva XYZ

La documentación oficial de
[MapLibre Native Android](https://github.com/maplibre/maplibre-native/blob/main/platform/android/docs/data/PMTiles.md)
indica: **“PMTiles sources do not support offline pack downloads or caching.”**
Por eso leer `pmtiles://` no basta para cumplir la descarga de regiones exigida por C2.
La [documentación de PMTiles CLI](https://docs.protomaps.com/pmtiles/cli#serve) ofrece un
servidor Z/X/Y que los renderizadores web y nativos pueden consumir sin protocolo PMTiles.
Esta entrega verifica esa salida HTTP y el visor; la descarga real en Android/iOS se valida en C2.

### Uso, atribución y licencias

- [Protomaps Downloads](https://docs.protomaps.com/basemaps/downloads) declara la distribución
  como obra producida bajo ODbL y exige atribución a OpenStreetMap. Documenta los recortes con
  `extract` y recomienda alojar una copia propia en lugar de enlazar directamente sus builds.
- El estilo y el visor incluyen **© OpenStreetMap contributors**; se conservan las referencias
  y avisos en `infra/cdn/publico/licencias/`.
- La capa `landcover` añade atribución a ESA WorldCover y enlace CC BY 4.0 según el aviso de
  datos de Protomaps; el aviso completo se conserva en `protomaps-datos.txt`.
- [basemaps-assets](https://github.com/protomaps/basemaps-assets/tree/028c18f713baecad011301ff7a69acc39bcc2ae7)
  declara fuentes bajo SIL OFL e iconos derivados de Tangram/Mapzen bajo MIT. Se conserva
  `fuentes/OFL.txt` y el aviso MIT.
- El código cartográfico Protomaps y MapLibre GL JS conserva su licencia BSD de tres cláusulas.

No se afirma haber aprobado términos comerciales de terceros ni se crea una cuenta de proveedor.

## Consecuencias

- C1 funciona con dos servicios propios (`cdn` y `teselas`); no requiere backend ni PowerSync.
- La descarga y el visor no dependen de servidores externos de fuentes, iconos o JavaScript
  una vez generados los recursos. El visor web no constituye una prueba de app móvil offline.
- Los binarios generados no se suben a Git. Scripts y configuración sí; un manifiesto local
  registra tamaño y SHA-256 del recorte.
- La retención de los builds diarios es limitada. El equipo debe conservar el recorte y el
  manifiesto en su almacenamiento o revisar explícitamente la configuración para regenerar
  con otra fecha. No se cambia de fuente silenciosamente.
- La descarga y el tamaño total en un Android de gama baja, así como iOS, se miden en C2.
  El tamaño del PMTiles no equivale al tamaño de una región offline con fuentes y sprites.

## Verificación

Ver `docs/fase-0/evidencias/fuente-de-teselas.md`. Se requiere la aprobación de esta decisión y
la ejecución del flujo de CI antes de considerar C1 integrada.
