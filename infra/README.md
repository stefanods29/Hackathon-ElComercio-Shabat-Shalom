# Infraestructura local

`docker compose up -d` levanta PostgreSQL 18 + PostGIS 3.6 (replicación lógica para PowerSync),
el servicio de PowerSync (`powersync/service.yaml`, Sync Streams en `powersync/sync-config.yaml`)
y una CDN nginx con soporte de Range para las teselas PMTiles (`cdn/`). Valida los Sync Streams
con `cd ../backend && npm run sync:validate`.
