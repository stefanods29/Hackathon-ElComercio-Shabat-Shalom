# Lote B · Directorio, reputación y moderación (Fase 1)

| Dato | Valor |
|---|---|
| Dificultad | ★★★ Media-alta |
| Área | `backend/src/modules/directorio/`, `reputacion/`, `moderacion/`, `identidad/`, `contracts/openapi.yaml`, `backend/src/workers/` |
| Change de OpenSpec | `openspec/changes/fase-1-lote-b-directorio-reputacion-y-moderacion/` (proposal, design, specs, tasks) |
| Partes | 5. La 1 va primero; la 4 y la 5 pueden avanzar en paralelo con la 2 y la 3 |
| Depende de | Precisión de ubicación (A parte 1), archivos de C (parte 1) para las fotos |

## Estado del lote

| Parte | Qué entrega | Estado | Responsable | PR |
|---|---|---|---|---|
| 1 | Directorio: categorías, proveedores y servicios | Lista para revisión | JDiazD33 | — |
| 2 | Búsqueda por cercanía y texto | Lista para revisión | JDiazD33 | — |
| 3 | Reseñas, Visto Bueno y ranking | Lista para revisión | JDiazD33 | — |
| 4 | Identidad del piloto: niveles, zona y privacidad | Lista para revisión | JDiazD33 | [Entrega](parte-4.md) |
| 5 | Moderación | Lista para revisión | JDiazD33 | [Entrega](parte-5.md) |

Estados posibles: **Pendiente**, **En curso**, **Lista para revisión** (código entregado,
comprobaciones y aprobación a cargo del supervisor) o **Hecha** (integrada en `main`).

La Parte 1 se entrega en `f1-lote-b/parte-1-directorio`, sin PR ni integración. Su alcance,
cobertura escrita y comandos pendientes están en [el informe de la parte](parte-1.md).
La Parte 2 se entrega en `f1-lote-b/parte-2-busqueda`, desde la punta de la Parte 1;
ver [su informe](parte-2.md) y la [consulta de EXPLAIN](../evidencias/busqueda.md).
La Parte 3 se entrega en `f1-lote-b/parte-3-resenas`, desde la punta de la Parte 2;
ver [su informe](parte-3.md).

---

## 0. Antes de empezar

### 0.1 Reglas

Las de la Fase 0 ([`../../fase-0/lote-b-api-identidad-y-trabajos/README.md`](../../fase-0/lote-b-api-identidad-y-trabajos/README.md))
y las [reglas comunes de la fase](../README.md#reglas-para-todos-los-lotes). Cada módulo es dueño
de su esquema; entre módulos se usa el `index.ts` o eventos del outbox (`npm run boundaries`).
Toda escritura que el celular reintenta lleva `@Idempotent()`. Primero el contrato.

### 0.2 Lo que ya existe

- Patrón de referencia: `backend/src/modules/solidaridad/` (dominio, casos de uso, repositorio
  Kysely y en memoria, controlador y esquemas Zod).
- Roles y nivel de confianza con `@RequireRole()` y `@RequireTrustLevel()`; pg-boss, relay del
  outbox, `JobHandlerRegistry` y workers en `backend/src/workers/` (Lote B de la Fase 0).
- Los módulos `directorio`, `reputacion` y `moderacion` existen como esqueletos.

---

## Parte 1 · Directorio: categorías, proveedores y servicios

Tablas en el esquema `directorio` (sección 5.3): `categorias` (con `util_en_emergencia`),
`proveedores` (perfil de un vecino que ofrece servicios) y `servicios`. Esta última lleva la
ubicación exacta, la copia pública (ADR 0010), `radio_cobertura_m`, `disponible_en_emergencia`,
`atributos` (`jsonb`), los agregados que calcula la parte 3, `version` y `eliminado_en`.

Rutas:

| Ruta | Qué hace | Reglas |
|---|---|---|
| `GET /v1/categorias` | Lista de categorías | Pública con token |
| `PUT /v1/yo/proveedor` | Crea o actualiza mi perfil de proveedor | `@Idempotent()`, nivel 1 |
| `POST /v1/servicios` | Publica un servicio | `@Idempotent()`, nivel 1; evento `directorio.servicio_publicado` |
| `PUT /v1/servicios/{id}` | Edita con `version` | 409 `conflicto_de_version` si cambió (el código que ya traduce la app) |
| `DELETE /v1/servicios/{id}` | Borrado lógico | Solo el dueño; idempotente |
| `GET /v1/proveedores/{id}` | Perfil con sus servicios | Sin teléfono ni ubicación exacta |

Pruebas: dominio (dueño, versión, borrado), integración con PostgreSQL (rutas, 401, 403, 409) y el
contrato con `redocly lint`.

## Parte 2 · Búsqueda por cercanía y texto

- `GET /v1/servicios?lat&lng&radioM&categoriaId&q&soloEmergencia&cursor` con la consulta de la
  sección 5.4: `ST_DWithin` sobre el índice GiST, orden por Visto Bueno de vecinos verificados de
  mi zona y luego por `puntaje_ranking`, y paginación por cursor.
- Búsqueda tolerante: columna `tsvector` con configuración `spanish`, `unaccent` envuelta como
  `IMMUTABLE` e índice `pg_trgm` sobre `titulo` ("gásfiter" encuentra "gasfitero").
- La respuesta da `distanciaMetros` y la ubicación pública, nunca la exacta.

Pruebas: integración con datos sembrados (radio, categoría, texto con y sin tildes, cursor estable)
y un `EXPLAIN` que confirme el uso de los índices en la evidencia del PR.

## Parte 3 · Reseñas, Visto Bueno y ranking

- **Reseñas** (`reputacion.resenas` y `resena_fotos`): el `id` lo genera el celular (UUIDv7), una
  por vecino y servicio (409 `resena_duplicada`) y nadie se reseña a sí mismo (403
  `no_puedes_resenarte`). Entra como `en_revision` junto con su evento en la misma transacción.
  Las fotos se enlazan por `archivoId` de C y no se publican antes de la reseña.
- **Visto Bueno:** `POST` y `DELETE /v1/servicios/{id}/visto-bueno`, uno por vecino y servicio.
  Solo cuenta para el ranking el de nivel 2 o más.
- **Ranking bayesiano** (sección 5.5): un worker recalcula `total_resenas`, `promedio`,
  `puntaje_ranking` y `total_vistos_buenos` a partir de todas las reseñas publicadas, nunca
  sumando incrementos, así que un reintento no lo descuadra.
- **Antifraude:** antigüedad mínima de la cuenta, límites diarios y detección de patrones (muchas
  reseñas desde el mismo dispositivo); los casos dudosos van a moderación.

Pruebas: dominio de cada regla, integración de rutas y worker (reintento sin descuadre) y una
prueba que compare el puntaje con el cálculo a mano.

## Parte 4 · Identidad del piloto: niveles, zona y privacidad

- **Nivel 1 · residencia confirmada.** Se decide en un ADR. Propuesta: con consentimiento, el
  celular informa una vez al día solo si estuvo dentro del polígono de su zona (sin coordenadas);
  3 días distintos en 14 suben al nivel 1. También puede confirmarlo a mano un moderador o la
  junta vecinal. Evento `identidad.residencia_confirmada`.
- **Nivel 2 · aval:** `POST /v1/vecinos/{id}/aval` (`@Idempotent()`), dado por un vecino de nivel 2
  o más de la misma zona, nunca a sí mismo; con 2 avales sube al nivel 2. Los primeros de nivel 2
  los valida la junta vecinal.
- **Cambio de zona:** `PUT /v1/yo/zona` deja de responder 409 `zona_ya_elegida` y permite cambiar
  con un límite (por ejemplo, una vez cada 30 días). Al cambiar, el nivel vuelve a 0 hasta
  confirmar la nueva residencia.
- **Consentimiento y ARCO** (Ley 29733): `GET` y `POST /v1/yo/consentimientos` (finalidad y
  versión del texto); `GET /v1/yo/datos` (exporta mis datos); `PATCH /v1/yo` (rectifica);
  `DELETE /v1/yo` (cancela: revoca sesiones, borra datos personales y anonimiza lo público con un
  trabajo); oposición por finalidad (por ejemplo, la confirmación por presencia).

Pruebas: integración de cada ruta y del trabajo de borrado (no quedan datos personales) y una
prueba de que sin consentimiento no se trata la presencia.

## Parte 5 · Moderación

- `POST /v1/denuncias` (`@Idempotent()`): denuncia una publicación, reseña, servicio o foto, con un
  motivo de una lista cerrada.
- Cadena de filtros (sección 4.3): texto → imagen (con C) → reputación del autor → revisión humana.
  Lo dudoso entra a la cola `moderacion.casos`.
- Rol `moderador`: `GET /v1/moderacion/casos?estado&cursor` y
  `POST /v1/moderacion/casos/{id}/decision` (`ocultar`, `restaurar`, `descartar` o `sancionar`, con
  motivo). Ocultar emite `moderacion.contenido_ocultado` y el módulo dueño marca el contenido, que
  sale de los streams.
- Las reseñas *en revisión* se publican o se ocultan desde esta cola, y al publicarse el worker
  recalcula el ranking.

Pruebas: integración (denuncia → caso → decisión → contenido oculto), permisos del rol y la
métrica de tiempo hasta la primera revisión para el criterio de salida.

---

## Puntos de contacto con otros lotes

- **A:** copia pública de la ubicación, nombres de columnas para los streams y ruta de telemetría.
- **C:** `archivoId` de las fotos y moderación de imágenes; avisos de "tu reseña se publicó".
- **D:** contrato de cada ruta y códigos de error para mostrar el motivo.

## Fuera de alcance

Validación de DNI (nivel 3) y módulo Emergencias (Fase 2); Valkey, réplicas y extracción de
servicios (Fase 3).

## Definición de terminado del lote

Las 5 partes aprobadas e integradas, el contrato y los Sync Streams coherentes, el grafo
actualizado y la evidencia de moderación y privacidad lista para los criterios de salida.
