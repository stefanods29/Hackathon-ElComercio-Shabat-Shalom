# Infraestructura local

`docker compose up -d` levanta PostgreSQL 18 + PostGIS 3.6 (replicación lógica para PowerSync),
el servicio de PowerSync (`powersync/service.yaml`, Sync Streams en `powersync/sync-config.yaml`)
y una CDN nginx con soporte de Range para las teselas PMTiles (`cdn/`). Valida los Sync Streams
con `cd ../backend && npm run sync:validate`.

El Lote C agrega el servidor XYZ `teselas`, que lee el mismo PMTiles local que sirve nginx.
Para trabajar solo los mapas: genera los archivos siguiendo `cdn/README.md` y ejecuta
`docker compose up -d cdn`; no necesita iniciar PostgreSQL, PowerSync ni la API.

Para las fotos de Fase 1 C, usar la composición adicional `compose.media.yml` siguiendo
`media/README.md`. La propuesta de entornos cloud y su validación sin despliegue están en
`cloud/README.md`; no requiere ni incorpora credenciales reales para sus pruebas locales.

## Laboratorio de PowerSync en vivo

La composición adicional `compose.powersync-live.yml` fija PowerSync 1.28.1 y apunta el JWKS
a la API efímera que levanta la prueba en el puerto 3001. Usar un proyecto de Compose separado
y una base local de laboratorio; los puertos 5432 y 8080 deben estar libres. No ejecutar contra
datos de personas. Los comandos y el alcance de las comprobaciones están en
[`powersync-en-vivo.md`](../docs/fase-2/evidencias/powersync-en-vivo.md).
