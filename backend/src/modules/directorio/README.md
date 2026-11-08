# Módulo `directorio`

Categorías, perfiles de proveedor y servicios. Es dueño de `directorio.*`; los demás módulos
solo importan su `index.ts` o consumen eventos del outbox.

| Operación | Regla |
|---|---|
| `GET /v1/categorias` | Sesión, categorías ordenadas por `orden` e `id` |
| `PUT /v1/yo/proveedor` | Sesión, zona, nivel 1, `Idempotency-Key` |
| `GET /v1/servicios` | Sesión y zona; cercanía, categoría, texto, emergencia y cursor |
| `POST /v1/servicios` | Perfil vigente de la zona, nivel 1; 201 al crear, 200 para un id propio existente |
| `PUT /v1/servicios/{id}` | Dueño, `versionVista`, `Idempotency-Key` |
| `DELETE /v1/servicios/{id}` | Dueño, retiro lógico idempotente, `Idempotency-Key` |
| `GET /v1/proveedores/{id}` | Sesión, perfil y servicios vigentes sin datos de contacto |

El dominio guarda la ubicación exacta separada de `publicLocation`. Esta última se redondea a
3 decimales, salvo aceptación explícita de `muestraUbicacionExacta` para publicar un local.
Editar sin esa aceptación vuelve a redondear. La API proyecta campos explícitos: nunca devuelve
`location` privada ni teléfono. La precisión sigue la decisión 2 del Lote A y el ADR 0010.

Los atributos admiten hasta 4096 bytes de JSON UTF-8, validados en Zod y en el dominio.
Las escrituras se serializan por proveedor con un bloqueo transaccional. Las ediciones además
comparan `version` al guardar. La creación del servicio y `directorio.servicio_publicado` se
confirman o revierten en la misma unidad de trabajo. Los reintentos de un id propio no crean otro
evento, no reemplazan su contenido y no reactivan un servicio retirado.

Un retiro procesado o repetido con una clave nueva devuelve 204. El interceptor compartido
responde 200 con `Idempotent-Replayed: true` al reutilizar la misma clave, igual que las bajas de
dispositivos; no se altera ese comportamiento transversal.

`ZoneChangedHandler` se registra en `JobHandlerRegistry`, tanto en la API como en el proceso de
workers que importa `DirectoryModule`. Espera el sobre del relay de `identidad.zona_cambiada`:

```json
{
  "eventoId": "01970000-0000-7000-8000-000000000111",
  "modulo": "identidad",
  "agregadoId": "01970000-0000-7000-8000-0000000000b1",
  "ocurridoEn": "2026-11-08T01:00:00Z",
  "carga": {
    "zonaAnteriorId": "01970000-0000-7000-8000-000000000001",
    "zonaId": "01970000-0000-7000-8000-000000000002"
  }
}
```

El agregado identifica al vecino. El manejador retira solo sus servicios no retirados de la zona
anterior; no mueve el perfil ni toca la zona nueva. La emisión del evento queda para la Parte 4.

La migración `202611080100_directorio_base` crea y publica `categorias`, `proveedores` y `servicios`
en `powersync`, con `SELECT` para `powersync_rol` si existe. Siembra seis categorías con ids de
texto e iconos Material. `scripts/seed-data.ts` añade tres servicios ficticios en las dos zonas,
sin publicar coordenadas exactas y sin duplicarlos al repetir la semilla.

`GET /v1/servicios` busca exclusivamente servicios y proveedores vigentes de la zona del token.
Usa `ST_DWithin` con la ubicación privada, texto en español sin tildes sobre título y descripción,
y similitud de palabras sobre el título para errores leves. El umbral de trigramas es 0,3 dentro
de la transacción y se restaura al finalizar. No guarda el punto de búsqueda y solo proyecta
campos públicos y la distancia redondeada a múltiplos de 50 m.

El orden es `vistos_buenos_de_la_zona DESC, puntaje_ranking DESC, id ASC`. El cursor `base64url`
lleva únicamente esos valores (`v`, `p`, `id`); no busca la fila anterior, por lo que sigue siendo
usable si esta se retira. Debe conservar los filtros. No ofrece una instantánea ante cambios de
ranking entre páginas.

`202611080110_directorio_busqueda` añade `sin_tildes` inmutable, el `tsvector` generado
`busqueda`, dos índices GIN de texto y un índice de zona/orden. Reutiliza el GiST existente y no
añade tablas a `powersync`.
La consulta de `EXPLAIN` para el supervisor está en
[`docs/fase-1/evidencias/busqueda.md`](../../../../docs/fase-1/evidencias/busqueda.md), sin salidas inventadas.

El consumidor de `reputacion.agregados_recalculados` sustituye los contadores del servicio y
recalcula el puntaje de su categoría con peso 7 y media ponderada por reseñas publicadas de sus
servicios vigentes. Usa el id y la fecha del evento para omitir reintentos o entregas más viejas;
la marca es privada y se confirma junto con los agregados. El recálculo no cambia la versión de
edición de un servicio.

Las entregas y su cobertura están en
[Parte 1](../../../../docs/fase-1/lote-b-directorio-reputacion-y-moderacion/parte-1.md) y
[Parte 2](../../../../docs/fase-1/lote-b-directorio-reputacion-y-moderacion/parte-2.md) y
[Parte 3](../../../../docs/fase-1/lote-b-directorio-reputacion-y-moderacion/parte-3.md).
