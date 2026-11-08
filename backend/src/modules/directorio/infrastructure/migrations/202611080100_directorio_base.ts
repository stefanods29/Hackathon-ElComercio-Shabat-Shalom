import { type Kysely, sql } from 'kysely';

export async function up(db: Kysely<unknown>): Promise<void> {
  await sql
    .raw(
      `
CREATE SCHEMA directorio;

CREATE TABLE directorio.categorias (
  id text PRIMARY KEY CHECK (id ~ '^[a-z0-9-]{2,40}$'),
  nombre text NOT NULL UNIQUE,
  icono text NOT NULL,
  util_en_emergencia boolean NOT NULL DEFAULT false,
  orden int NOT NULL,
  actualizado_en timestamptz NOT NULL DEFAULT now()
);
INSERT INTO directorio.categorias (id, nombre, icono, util_en_emergencia, orden) VALUES
  ('gasfiteria', 'Gasfitería', 'plumbing', true, 10),
  ('electricidad', 'Electricidad', 'electrical_services', true, 20),
  ('carpinteria', 'Carpintería', 'carpenter', false, 30),
  ('clases', 'Clases particulares', 'school', false, 40),
  ('mascotas', 'Cuidado de mascotas', 'pets', false, 50),
  ('limpieza', 'Limpieza', 'cleaning_services', false, 60);

CREATE TABLE directorio.proveedores (
  id uuid PRIMARY KEY REFERENCES identidad.usuarios(id),
  zona_id uuid NOT NULL REFERENCES identidad.zonas(id),
  nombre_publico text NOT NULL CHECK (char_length(nombre_publico) BETWEEN 2 AND 60),
  descripcion text CHECK (char_length(descripcion) <= 500),
  creado_en timestamptz NOT NULL DEFAULT now(),
  actualizado_en timestamptz NOT NULL DEFAULT now(),
  eliminado_en timestamptz,
  oculto_en timestamptz
);
CREATE INDEX proveedores_zona_idx ON directorio.proveedores (zona_id)
  WHERE eliminado_en IS NULL AND oculto_en IS NULL;

CREATE TABLE directorio.servicios (
  id uuid PRIMARY KEY CHECK (substring(id::text FROM 15 FOR 1) = '7'),
  proveedor_id uuid NOT NULL REFERENCES directorio.proveedores(id),
  zona_id uuid NOT NULL REFERENCES identidad.zonas(id),
  categoria_id text NOT NULL REFERENCES directorio.categorias(id),
  titulo text NOT NULL CHECK (char_length(titulo) BETWEEN 3 AND 120),
  descripcion text CHECK (char_length(descripcion) <= 2000),
  ubicacion geography(Point, 4326) NOT NULL,
  lat_publica double precision NOT NULL CHECK (lat_publica BETWEEN -90 AND 90),
  lng_publica double precision NOT NULL CHECK (lng_publica BETWEEN -180 AND 180),
  muestra_ubicacion_exacta boolean NOT NULL DEFAULT false,
  radio_cobertura_m int NOT NULL DEFAULT 2000 CHECK (radio_cobertura_m BETWEEN 100 AND 20000),
  disponible_en_emergencia boolean NOT NULL DEFAULT false,
  atributos jsonb NOT NULL DEFAULT '{}' CHECK (jsonb_typeof(atributos) = 'object'),
  total_resenas int NOT NULL DEFAULT 0 CHECK (total_resenas >= 0),
  suma_calificaciones int NOT NULL DEFAULT 0 CHECK (suma_calificaciones >= 0),
  promedio numeric(3,2) NOT NULL DEFAULT 0 CHECK (promedio BETWEEN 0 AND 5),
  puntaje_ranking numeric(6,4) NOT NULL DEFAULT 0 CHECK (puntaje_ranking BETWEEN 0 AND 5),
  total_vistos_buenos int NOT NULL DEFAULT 0 CHECK (total_vistos_buenos >= 0),
  vistos_buenos_de_la_zona int NOT NULL DEFAULT 0 CHECK (vistos_buenos_de_la_zona >= 0),
  version int NOT NULL DEFAULT 1 CHECK (version >= 1),
  creado_en timestamptz NOT NULL DEFAULT now(),
  actualizado_en timestamptz NOT NULL DEFAULT now(),
  eliminado_en timestamptz,
  oculto_en timestamptz
);
CREATE INDEX servicios_zona_idx ON directorio.servicios (zona_id, categoria_id)
  WHERE eliminado_en IS NULL AND oculto_en IS NULL;
CREATE INDEX servicios_proveedor_idx ON directorio.servicios (proveedor_id);
CREATE INDEX servicios_ubicacion_gix ON directorio.servicios USING gist (ubicacion);
CREATE INDEX servicios_atributos_gin ON directorio.servicios USING gin (atributos);

-- Solo los Sync Streams deciden las columnas públicas; nunca seleccionan ubicacion.
ALTER PUBLICATION powersync ADD TABLE directorio.categorias, directorio.proveedores,
  directorio.servicios;
DO $bloque$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'powersync_rol') THEN
    GRANT USAGE ON SCHEMA directorio TO powersync_rol;
    GRANT SELECT ON directorio.categorias, directorio.proveedores, directorio.servicios
      TO powersync_rol;
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
ALTER PUBLICATION powersync DROP TABLE directorio.servicios, directorio.proveedores,
  directorio.categorias;
DROP TABLE directorio.servicios;
DROP TABLE directorio.proveedores;
DROP TABLE directorio.categorias;
DROP SCHEMA directorio;
`,
    )
    .execute(db);
}
