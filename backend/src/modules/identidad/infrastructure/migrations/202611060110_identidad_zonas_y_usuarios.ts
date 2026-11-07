import { type Kysely, sql } from 'kysely';

/**
 * Esquema `identidad`: zonas (polígonos del vecindario) y usuarios con su nivel de confianza.
 * Las sesiones y los OTP los agrega el Lote B en sus propias migraciones.
 */
export async function up(db: Kysely<unknown>): Promise<void> {
  await sql
    .raw(
      `
CREATE SCHEMA IF NOT EXISTS identidad;

CREATE TABLE identidad.zonas (
  id              uuid        PRIMARY KEY DEFAULT uuidv7(),
  nombre          text        NOT NULL,
  distrito        text        NOT NULL,
  limite          geography(MultiPolygon, 4326) NOT NULL,
  creado_en       timestamptz NOT NULL DEFAULT now(),
  actualizado_en  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX zonas_limite_gix ON identidad.zonas USING gist (limite);

CREATE TABLE identidad.usuarios (
  id               uuid        PRIMARY KEY DEFAULT uuidv7(),
  telefono         text        NOT NULL UNIQUE CHECK (telefono ~ '^\\+[1-9][0-9]{7,14}$'),
  nombre_visible   text        NOT NULL CHECK (char_length(nombre_visible) BETWEEN 2 AND 60),
  zona_id          uuid        REFERENCES identidad.zonas(id),
  nivel_confianza  smallint    NOT NULL DEFAULT 0 CHECK (nivel_confianza BETWEEN 0 AND 3),
  roles            text[]      NOT NULL DEFAULT '{}'
                               CHECK (roles <@ ARRAY['proveedor', 'moderador', 'coordinador', 'brigadista', 'administrador']::text[]),
  creado_en        timestamptz NOT NULL DEFAULT now(),
  actualizado_en   timestamptz NOT NULL DEFAULT now(),
  eliminado_en     timestamptz
);
CREATE INDEX usuarios_zona_idx ON identidad.usuarios (zona_id) WHERE eliminado_en IS NULL;

-- Replicada para PowerSync; los Sync Streams eligen qué columnas llegan al celular (el polígono no).
ALTER PUBLICATION powersync ADD TABLE identidad.zonas;

DO $bloque$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'powersync_rol') THEN
    GRANT USAGE ON SCHEMA identidad TO powersync_rol;
    GRANT SELECT ON identidad.zonas TO powersync_rol;
  END IF;
END
$bloque$;
`,
    )
    .execute(db);
}

export async function down(db: Kysely<unknown>): Promise<void> {
  await sql
    .raw(
      `
ALTER PUBLICATION powersync DROP TABLE identidad.zonas;
DROP TABLE IF EXISTS identidad.usuarios;
DROP TABLE IF EXISTS identidad.zonas;
DROP SCHEMA IF EXISTS identidad;
`,
    )
    .execute(db);
}
