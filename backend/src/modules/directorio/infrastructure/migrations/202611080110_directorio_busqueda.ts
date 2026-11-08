import { type Kysely, sql } from 'kysely';

export async function up(db: Kysely<unknown>): Promise<void> {
  await sql
    .raw(
      `
CREATE FUNCTION directorio.sin_tildes(text) RETURNS text
LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
SET search_path = pg_catalog, public
AS $funcion$
  SELECT public.unaccent('public.unaccent'::regdictionary, $1)
$funcion$;

ALTER TABLE directorio.servicios ADD COLUMN busqueda tsvector
  GENERATED ALWAYS AS (
    setweight(to_tsvector('spanish'::regconfig, directorio.sin_tildes(titulo)), 'A') ||
    setweight(to_tsvector('spanish'::regconfig, directorio.sin_tildes(coalesce(descripcion, ''))), 'B')
  ) STORED;
CREATE INDEX servicios_busqueda_gin ON directorio.servicios USING gin (busqueda)
  WHERE eliminado_en IS NULL AND oculto_en IS NULL;
CREATE INDEX servicios_titulo_trgm_gin ON directorio.servicios
  USING gin (directorio.sin_tildes(titulo) public.gin_trgm_ops)
  WHERE eliminado_en IS NULL AND oculto_en IS NULL;
CREATE INDEX servicios_orden_idx ON directorio.servicios
  (zona_id, vistos_buenos_de_la_zona DESC, puntaje_ranking DESC, id)
  WHERE eliminado_en IS NULL AND oculto_en IS NULL;
`,
    )
    .execute(db);
}

export async function down(db: Kysely<unknown>): Promise<void> {
  await sql
    .raw(
      `
DROP INDEX directorio.servicios_orden_idx;
DROP INDEX directorio.servicios_titulo_trgm_gin;
DROP INDEX directorio.servicios_busqueda_gin;
ALTER TABLE directorio.servicios DROP COLUMN busqueda;
DROP FUNCTION directorio.sin_tildes(text);
`,
    )
    .execute(db);
}
