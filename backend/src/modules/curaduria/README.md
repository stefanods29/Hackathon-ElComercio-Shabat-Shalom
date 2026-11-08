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
3. **Concurrencia:** un bloqueo por archivo (`pg_advisory_xact_lock`) serializa a los curadores. La
   versión actual es la mayor entre el índice y `curaduria.versiones_directorio`. Si `versionVista`
   no es la actual, 409 `conflicto_de_version`.
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
- **Pendiente:** el adaptador del almacenamiento de la CDN en la nube, alineado con el de la Fase
  1, Lote C. La caché de la CDN se purga en `emergencia/` al publicar.
