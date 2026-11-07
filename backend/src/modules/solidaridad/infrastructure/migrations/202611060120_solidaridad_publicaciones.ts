import { type Kysely, sql } from 'kysely';

/**
 * Muro de favores. El `id` lo genera el celular (UUIDv7) para que los reintentos sin señal no
 * dupliquen publicaciones. `version` permite la concurrencia optimista al tomar un favor.
 * `lat`/`lng` son aproximados (≈100 m): nunca se publica la ubicación exacta de una persona.
 */
export async function up(db: Kysely<unknown>): Promise<void> {
  await sql
    .raw(
      `
CREATE SCHEMA IF NOT EXISTS solidaridad;

CREATE TABLE solidaridad.publicaciones (
  id              uuid        PRIMARY KEY,
  autor_id        uuid        NOT NULL REFERENCES identidad.usuarios(id),
  zona_id         uuid        NOT NULL REFERENCES identidad.zonas(id),
  tipo            text        NOT NULL
                  CHECK (tipo IN ('ofrezco', 'necesito', 'presto', 'dono', 'intercambio', 'movilidad')),
  categoria       text        NOT NULL CHECK (char_length(categoria) BETWEEN 2 AND 40),
  titulo          text        NOT NULL CHECK (char_length(titulo) BETWEEN 3 AND 120),
  descripcion     text        CHECK (char_length(descripcion) <= 2000),
  lat             double precision CHECK (lat BETWEEN -90 AND 90),
  lng             double precision CHECK (lng BETWEEN -180 AND 180),
  ubicacion       geography(Point, 4326),
  estado          text        NOT NULL DEFAULT 'abierta'
                  CHECK (estado IN ('abierta', 'en_curso', 'resuelta', 'cancelada')),
  tomada_por_id   uuid        REFERENCES identidad.usuarios(id),
  version         int         NOT NULL DEFAULT 1 CHECK (version >= 1),
  vence_en        timestamptz,
  creado_en       timestamptz NOT NULL DEFAULT now(),
  actualizado_en  timestamptz NOT NULL DEFAULT now(),
  eliminado_en    timestamptz,
  CHECK ((lat IS NULL) = (lng IS NULL)),
  CHECK (tomada_por_id IS NULL OR tomada_por_id <> autor_id)
);
CREATE INDEX publicaciones_zona_idx ON solidaridad.publicaciones (zona_id, creado_en DESC)
  WHERE eliminado_en IS NULL;
CREATE INDEX publicaciones_autor_idx ON solidaridad.publicaciones (autor_id);
CREATE INDEX publicaciones_ubicacion_gix ON solidaridad.publicaciones USING gist (ubicacion);

-- Replicada para PowerSync. Los Sync Streams no seleccionan la columna geography: al celular
-- solo llegan lat/lng aproximados.
ALTER PUBLICATION powersync ADD TABLE solidaridad.publicaciones;

DO $bloque$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'powersync_rol') THEN
    GRANT USAGE ON SCHEMA solidaridad TO powersync_rol;
    GRANT SELECT ON solidaridad.publicaciones TO powersync_rol;
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
ALTER PUBLICATION powersync DROP TABLE solidaridad.publicaciones;
DROP TABLE IF EXISTS solidaridad.publicaciones;
DROP SCHEMA IF EXISTS solidaridad;
`,
    )
    .execute(db);
}
