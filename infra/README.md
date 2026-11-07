# Infraestructura local

`docker compose up -d` levanta PostgreSQL 18 + PostGIS 3.6 (replicación lógica para PowerSync),
el servicio de PowerSync (`powersync/service.yaml`, Sync Streams en `powersync/sync-config.yaml`)
y una CDN nginx con soporte de Range para las teselas PMTiles (`cdn/`). Valida los Sync Streams
con `cd ../backend && npm run sync:validate`.

El Lote C agrega el servidor XYZ `teselas`, que lee el mismo PMTiles local que sirve nginx.
Para trabajar solo los mapas: genera los archivos siguiendo `cdn/README.md` y ejecuta
`docker compose up -d cdn`; no necesita iniciar PostgreSQL, PowerSync ni la API.
