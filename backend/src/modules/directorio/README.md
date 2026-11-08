# Módulo `directorio`

Categorías, perfiles de proveedor y servicios. Es dueño de `directorio.*`; los demás módulos
solo importan su `index.ts` o consumen eventos del outbox.

| Operación | Regla |
|---|---|
| `GET /v1/categorias` | Sesión, categorías ordenadas por `orden` e `id` |
| `PUT /v1/yo/proveedor` | Sesión, zona, nivel 1, `Idempotency-Key` |
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

La búsqueda de servicios, los índices de texto y `busqueda` quedan para la Parte 2. Los agregados
se crean en cero; la Parte 3 implementará su recálculo. El límite de esta entrega, las pruebas
escritas y la verificación pendiente están en
[`docs/fase-1/lote-b-directorio-reputacion-y-moderacion/parte-1.md`](../../../../docs/fase-1/lote-b-directorio-reputacion-y-moderacion/parte-1.md).
