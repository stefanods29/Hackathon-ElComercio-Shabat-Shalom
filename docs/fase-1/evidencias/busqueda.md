# Búsqueda de servicios · Consulta para revisión

**Estado:** consulta preparada, sin ejecutar. Parte 2 del Lote B, tarea 2.4.
No se dispone aún de un plan medido, tiempos ni evidencia de uso efectivo de índices.
El supervisor debe ejecutar lo siguiente después de aplicar las migraciones y la semilla.
Los puntos y la zona usados aquí son exclusivamente de demostración.

## Consulta completa

La proyección y los predicados equivalen a `serviceSearchQuery()` para la primera página,
`q=gásfiter`, categoría Gasfitería y solo servicios disponibles en emergencia. La API enlaza
los valores como parámetros y solo devuelve `distanciaMetros` redondeada a 50 m.

```sql
BEGIN;
SET LOCAL pg_trgm.word_similarity_threshold = 0.3;
ANALYZE directorio.servicios;
ANALYZE directorio.proveedores;

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)
SELECT s.id, s.proveedor_id, s.zona_id, s.categoria_id, s.titulo, s.descripcion,
       s.lat_publica, s.lng_publica, s.radio_cobertura_m, s.disponible_en_emergencia,
       s.atributos, s.total_resenas, s.promedio, s.puntaje_ranking,
       s.vistos_buenos_de_la_zona, s.version, s.creado_en, s.actualizado_en,
       s.eliminado_en,
       ST_Distance(s.ubicacion,
         ST_SetSRID(ST_MakePoint(-77.034567, -12.085678), 4326)::geography) AS distancia_m
FROM directorio.servicios s
JOIN directorio.proveedores p ON p.id = s.proveedor_id AND p.zona_id = s.zona_id
WHERE s.zona_id = '01970000-0000-7000-8000-000000000001'::uuid
  AND s.eliminado_en IS NULL AND s.oculto_en IS NULL
  AND p.eliminado_en IS NULL AND p.oculto_en IS NULL
  AND ST_DWithin(s.ubicacion,
      ST_SetSRID(ST_MakePoint(-77.034567, -12.085678), 4326)::geography, 2000)
  AND s.categoria_id = 'gasfiteria'
  AND s.disponible_en_emergencia = true
  AND (s.busqueda @@ websearch_to_tsquery('spanish', directorio.sin_tildes('gásfiter'))
       OR directorio.sin_tildes(s.titulo) %> directorio.sin_tildes('gásfiter'))
ORDER BY s.vistos_buenos_de_la_zona DESC, s.puntaje_ranking DESC, s.id ASC
LIMIT 21;
ROLLBACK;
```

El límite 21 permite devolver 20 filas y saber si hay una página siguiente. Para la siguiente
página se añade antes del `ORDER BY` este predicado, con los valores decodificados del cursor:

```sql
AND (
  s.vistos_buenos_de_la_zona < :vistos_buenos
  OR (s.vistos_buenos_de_la_zona = :vistos_buenos AND s.puntaje_ranking < :puntaje)
  OR (s.vistos_buenos_de_la_zona = :vistos_buenos AND s.puntaje_ranking = :puntaje
      AND s.id > :id::uuid)
)
```

Los nombres con `:` son parámetros ilustrativos que deben reemplazarse al usar la consola.
El código de la API usa parámetros enlazados de Kysely. No consulta el ancla ni necesita que el
servicio de ese id siga visible. No garantiza una instantánea si cambia el ranking entre páginas.

## Índices que revisar

| Índice | Propósito |
|---|---|
| `servicios_ubicacion_gix` (Parte 1) | GiST sobre `ubicacion`, predicado `ST_DWithin` |
| `servicios_busqueda_gin` | GIN del `tsvector` generado en español, título y descripción sin tildes |
| `servicios_titulo_trgm_gin` | GIN de `directorio.sin_tildes(titulo)` para errores leves |
| `servicios_orden_idx` | Zona y orden mixto: vistos buenos DESC, puntaje DESC, id ASC |

El operador `%>` es el conmutador de `<%` y permite búsqueda por similitud de palabras con índice
GIN. La transacción fija su umbral en 0,3 para corresponder a `word_similarity(q, titulo) > 0.3`,
en vez del valor predeterminado 0,6. La configuración es local y se restaura al terminar.
[Referencia oficial de pg_trgm](https://www.postgresql.org/docs/18/pgtrgm.html).

`sin_tildes` fija el diccionario `public.unaccent` y se declara `IMMUTABLE` para poder usarla en
la columna generada y el índice. La decisión presupone un diccionario fijo; si se cambian sus
reglas, una migración deberá recomputar la columna y reconstruir el índice de trigramas.
[Referencia del diccionario unaccent](https://www.postgresql.org/docs/18/unaccent.html).

Con las tres filas de demostración el optimizador puede preferir un recorrido secuencial. El
plan útil para capacidad debe medirse con un volumen representativo y estadísticas actualizadas;
no se debe presentar un plan forzado como evidencia de rendimiento.

## Diagnóstico separado de los predicados

Si el plan completo usa otro acceso por el tamaño de la semilla, estas consultas ayudan a revisar
cada expresión. `enable_seqscan=off` se usa solo para inspección de acceso candidato; los resultados
no sustituyen el plan natural ni prueban capacidad.

```sql
BEGIN;
SET LOCAL enable_seqscan = off;
SET LOCAL pg_trgm.word_similarity_threshold = 0.3;

EXPLAIN (COSTS, VERBOSE)
SELECT id FROM directorio.servicios
WHERE ST_DWithin(ubicacion,
  ST_SetSRID(ST_MakePoint(-77.034567, -12.085678), 4326)::geography, 500);

EXPLAIN (COSTS, VERBOSE)
SELECT id FROM directorio.servicios
WHERE eliminado_en IS NULL AND oculto_en IS NULL
  AND busqueda @@ websearch_to_tsquery('spanish', directorio.sin_tildes('tuberías'));

EXPLAIN (COSTS, VERBOSE)
SELECT id FROM directorio.servicios
WHERE eliminado_en IS NULL AND oculto_en IS NULL
  AND directorio.sin_tildes(titulo) %> directorio.sin_tildes('gasfitro');
ROLLBACK;
```

## Evidencia que falta registrar

El supervisor debe adjuntar el plan natural completo, cantidad de filas y tamaño de las tablas,
versión de PostgreSQL/PostGIS, nodos e índices elegidos, tiempos y buffers. Si hay recorridos
secuenciales, debe explicar su elección con ese conjunto de datos. Esta entrega no inventa
salidas de `EXPLAIN` ni marca la tarea 2.4 como aprobada.
