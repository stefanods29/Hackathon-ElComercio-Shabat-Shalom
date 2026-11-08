# Curaduría · Lote C (Fase 2)

Edita y publica el directorio de emergencia desde la consola de operación. Reemplaza la edición
por PR de la Fase 1.

- `GET /v1/operacion/directorio-emergencia`: lista los distritos del índice publicado.
- `GET /v1/operacion/directorio-emergencia/{archivo}`: lee la versión publicada, con su SHA-256.
- `PUT /v1/operacion/directorio-emergencia/{archivo}`: publica una versión nueva. Lleva
  `Idempotency-Key` y `versionVista`.

Roles: `administrador` y `coordinador`. El rol `curador` se suma cuando el Lote B (parte 5) lo
agregue al token.

## Publicar

1. **Forma:** el controlador valida la forma; si falla, 400 `validacion`.
2. **Contenido:** `application/directory-schema.ts` replica campo por campo
   `contracts/directorio-emergencia.schema.json`. `domain/` agrega dos reglas: identificadores
   únicos y ninguna `verificadoEn` en el futuro. Si falla, 422 `directorio_invalido` con `errores`.
3. **Concurrencia:** un bloqueo del índice compartido (`pg_advisory_xact_lock`) serializa las
   publicaciones, incluso las de distritos distintos. La versión actual es la mayor entre el índice
   y `curaduria.versiones_directorio`. Si `versionVista` no es la actual, 409 `conflicto_de_version`.
4. **Publicación**, en la misma transacción:
   - se registra la versión (contenido, SHA-256, tamaño, quién y cuándo);
   - se escribe `emergencia/<archivo>`;
   - se reescribe `emergencia/indice.json`, con el mismo formato que
     `infra/cdn/scripts/build-emergency-index.mjs`. Las zonas no cambian aquí.
   - Si falla la escritura en la CDN, la versión no queda registrada.

## Adaptadores (`CURATION_PUBLISH_DRIVER`)

- `filesystem`: escribe en `CURATION_PUBLIC_ROOT` (por defecto `../infra/cdn/publico`), con
  escritura atómica. Solo para desarrollo; la configuración lo prohíbe en producción.
- `disabled` (por defecto): las rutas responden 503 `servicio_no_disponible`.
- `s3`: lee y escribe JSON en `emergencia/` de un bucket dedicado al directorio. Requiere
  `CURATION_BUCKET`, `CURATION_ACCESS_KEY_ID` y `CURATION_SECRET_ACCESS_KEY`.
  Para MinIO, configura `CURATION_ENDPOINT`, `CURATION_REGION` y
  `CURATION_FORCE_PATH_STYLE=true`. En producción, un endpoint personalizado exige HTTPS.
  El índice usa `Cache-Control: public, max-age=60` y los archivos de distrito se revalidan
  con `Cache-Control: no-cache`.

## Verificación con MinIO local

Levanta `object-storage` con `infra/compose.media.yml` y PostgreSQL con PostGIS de laboratorio.
En `backend/`, ejecuta `npm run test:integration -- test/integration/curation-s3.int-spec.ts`
con `DATABASE_URL_ADMIN` y las variables de prueba `CURATION_TEST_S3_ENDPOINT`,
`CURATION_TEST_S3_ACCESS_KEY_ID` y `CURATION_TEST_S3_SECRET_ACCESS_KEY`. La prueba crea un
bucket temporal, publica dos distritos por la API y verifica que el índice conserva ambas
versiones y coincide en tamaño y SHA-256 con los archivos almacenados.

Para usar el adaptador fuera de la prueba, carga el índice y los archivos iniciales de
`infra/cdn/publico/emergencia/` bajo ese mismo prefijo. La API actualiza distritos que ya figuran
en el índice. La configuración del bucket público y de la CDN de staging requiere acuerdo del
equipo. La prueba local usa acceso firmado al almacenamiento.

Las escrituras del distrito y del índice son independientes en S3. Si se escribe el distrito y
falla la actualización del índice, el reintento con la misma versión vista puede volver a
publicar ambos objetos. Falta comprobar en staging cómo se recupera el CDN ante esa interrupción.
