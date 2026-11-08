import { sql, type RawBuilder, type Selectable } from 'kysely';
import type { ServiceSearchQuery } from '../application/search-ports.js';
import type { ServicesTable } from './tables.js';

const PUBLIC_COLUMNS = [
  'id',
  'proveedor_id',
  'zona_id',
  'categoria_id',
  'titulo',
  'descripcion',
  'lat_publica',
  'lng_publica',
  'radio_cobertura_m',
  'disponible_en_emergencia',
  'atributos',
  'total_resenas',
  'promedio',
  'puntaje_ranking',
  'vistos_buenos_de_la_zona',
  'version',
  'creado_en',
  'actualizado_en',
  'eliminado_en',
] as const;
export type ServiceSearchRow = Pick<Selectable<ServicesTable>, (typeof PUBLIC_COLUMNS)[number]> & {
  distancia_m: number;
};

/** Values stay bound parameters. The trigram operator uses the transaction's 0.3 threshold. */
export function serviceSearchQuery(query: ServiceSearchQuery): RawBuilder<ServiceSearchRow> {
  const point = sql`ST_SetSRID(ST_MakePoint(${query.location.lng}, ${query.location.lat}), 4326)::geography`;
  const category = query.categoryId ? sql`s.categoria_id = ${query.categoryId}` : sql`true`;
  const emergency = query.emergencyOnly ? sql`s.disponible_en_emergencia = true` : sql`true`;
  const text = query.text
    ? sql`(s.busqueda @@ websearch_to_tsquery('spanish', directorio.sin_tildes(${query.text}))
        OR directorio.sin_tildes(s.titulo) %> directorio.sin_tildes(${query.text}))`
    : sql`true`;
  const cursor = query.cursor
    ? sql`(s.vistos_buenos_de_la_zona < ${query.cursor.v}
        OR (s.vistos_buenos_de_la_zona = ${query.cursor.v} AND s.puntaje_ranking < ${query.cursor.p})
        OR (s.vistos_buenos_de_la_zona = ${query.cursor.v} AND s.puntaje_ranking = ${query.cursor.p}
            AND s.id > ${query.cursor.id}::uuid))`
    : sql`true`;
  return sql<ServiceSearchRow>`
    SELECT ${sql.join(PUBLIC_COLUMNS.map((column) => sql.ref(`s.${column}`)))},
      ST_Distance(s.ubicacion, ${point}) AS distancia_m
    FROM directorio.servicios s
    JOIN directorio.proveedores p ON p.id = s.proveedor_id AND p.zona_id = s.zona_id
    WHERE s.zona_id = ${query.zoneId}
      AND s.eliminado_en IS NULL AND s.oculto_en IS NULL
      AND p.eliminado_en IS NULL AND p.oculto_en IS NULL
      AND ST_DWithin(s.ubicacion, ${point}, ${query.radiusMeters})
      AND ${category} AND ${emergency} AND ${text} AND ${cursor}
    ORDER BY s.vistos_buenos_de_la_zona DESC, s.puntaje_ranking DESC, s.id ASC
    LIMIT ${query.limit + 1}
  `;
}
