import { type Kysely, sql } from 'kysely';

export async function up(db: Kysely<unknown>): Promise<void> {
  await sql
    .raw(
      `
CREATE SCHEMA reputacion;
CREATE TABLE reputacion.resenas (
  id uuid PRIMARY KEY CHECK (substring(id::text FROM 15 FOR 1) = '7'),
  servicio_id uuid NOT NULL REFERENCES directorio.servicios(id),
  autor_id uuid NOT NULL REFERENCES identidad.usuarios(id),
  zona_autor_id uuid NOT NULL REFERENCES identidad.zonas(id),
  calificacion smallint NOT NULL CHECK (calificacion BETWEEN 1 AND 5),
  comentario text CHECK (char_length(comentario) <= 2000),
  estado text NOT NULL DEFAULT 'en_revision' CHECK (estado IN ('en_revision', 'publicada', 'oculta')),
  motivo_estado text,
  creado_en timestamptz NOT NULL DEFAULT now(),
  actualizado_en timestamptz NOT NULL DEFAULT now(),
  publicada_en timestamptz,
  UNIQUE (servicio_id, autor_id),
  CHECK (estado <> 'publicada' OR publicada_en IS NOT NULL)
);
CREATE INDEX resenas_autor_fecha_idx ON reputacion.resenas (autor_id, creado_en);
CREATE INDEX resenas_publicadas_idx ON reputacion.resenas (servicio_id)
  INCLUDE (calificacion) WHERE estado = 'publicada';

CREATE TABLE reputacion.resena_fotos (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  resena_id uuid NOT NULL REFERENCES reputacion.resenas(id) ON DELETE CASCADE,
  archivo_id uuid NOT NULL,
  orden smallint NOT NULL CHECK (orden BETWEEN 0 AND 2),
  ancho int NOT NULL CHECK (ancho > 0),
  alto int NOT NULL CHECK (alto > 0),
  blurhash text,
  oculta_en timestamptz,
  UNIQUE (resena_id, orden),
  UNIQUE (resena_id, archivo_id)
);

CREATE TABLE reputacion.vistos_buenos (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  servicio_id uuid NOT NULL REFERENCES directorio.servicios(id),
  vecino_id uuid NOT NULL REFERENCES identidad.usuarios(id),
  nivel_al_dar smallint NOT NULL CHECK (nivel_al_dar BETWEEN 1 AND 3),
  zona_vecino_id uuid NOT NULL REFERENCES identidad.zonas(id),
  creado_en timestamptz NOT NULL DEFAULT now(),
  UNIQUE (servicio_id, vecino_id)
);
CREATE INDEX vistos_buenos_vecino_idx ON reputacion.vistos_buenos (vecino_id);

-- Señal privada, separada de las tablas que alimentan los Sync Streams.
CREATE TABLE reputacion.senales_resenas (
  resena_id uuid PRIMARY KEY REFERENCES reputacion.resenas(id) ON DELETE CASCADE,
  dispositivo_hash text NOT NULL CHECK (dispositivo_hash ~ '^[0-9a-f]{64}$'),
  creado_en timestamptz NOT NULL
);
CREATE INDEX senales_resenas_dispositivo_fecha_idx
  ON reputacion.senales_resenas (dispositivo_hash, creado_en, resena_id);

ALTER PUBLICATION powersync ADD TABLE reputacion.resenas, reputacion.resena_fotos,
  reputacion.vistos_buenos;
DO $bloque$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'powersync_rol') THEN
    GRANT USAGE ON SCHEMA reputacion TO powersync_rol;
    GRANT SELECT ON reputacion.resenas, reputacion.resena_fotos, reputacion.vistos_buenos
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
ALTER PUBLICATION powersync DROP TABLE reputacion.resenas, reputacion.resena_fotos,
  reputacion.vistos_buenos;
DROP TABLE reputacion.senales_resenas;
DROP TABLE reputacion.resena_fotos;
DROP TABLE reputacion.vistos_buenos;
DROP TABLE reputacion.resenas;
DROP SCHEMA reputacion;
  `,
    )
    .execute(db);
}
