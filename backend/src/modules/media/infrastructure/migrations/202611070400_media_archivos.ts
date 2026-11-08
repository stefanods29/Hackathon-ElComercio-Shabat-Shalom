import { type Kysely, sql } from 'kysely';

export async function up(db: Kysely<unknown>): Promise<void> {
  await sql
    .raw(
      `CREATE SCHEMA media;
    CREATE TABLE media.archivos (
      id uuid PRIMARY KEY, propietario_id uuid NOT NULL REFERENCES identidad.usuarios(id),
      zona_id uuid NOT NULL REFERENCES identidad.zonas(id), tipo_contenido text NOT NULL
        CHECK (tipo_contenido IN ('image/jpeg','image/png','image/webp')),
      bytes integer NOT NULL CHECK (bytes BETWEEN 1 AND 2097152), sha256 text NOT NULL CHECK (sha256 ~ '^[0-9a-f]{64}$'),
      estado text NOT NULL DEFAULT 'pendiente_subida' CHECK (estado IN ('pendiente_subida','en_cola','procesando','listo','rechazado','eliminado')),
      ancho integer, alto integer, blurhash text, motivo text, version_procesada uuid,
      creado_en timestamptz NOT NULL DEFAULT now(), actualizado_en timestamptz NOT NULL DEFAULT now(),
      intentos integer NOT NULL DEFAULT 0, disponible_en timestamptz NOT NULL DEFAULT now(),
      arrendamiento_id uuid, arrendado_hasta timestamptz, subida_hasta timestamptz,
      limpiar_despues timestamptz, limpiado_en timestamptz,
      CHECK (ancho IS NULL OR ancho BETWEEN 1 AND 1280), CHECK (alto IS NULL OR alto BETWEEN 1 AND 1280)
    );
    CREATE INDEX archivos_propietario_idx ON media.archivos(propietario_id, creado_en);
    CREATE INDEX archivos_cola_idx ON media.archivos(disponible_en) WHERE estado IN ('en_cola','procesando');
    CREATE INDEX archivos_limpieza_idx ON media.archivos(limpiar_despues) WHERE limpiado_en IS NULL;
    -- Quarantine and owner data never enter PowerSync automatic streams.
  `,
    )
    .execute(db);
}
export async function down(db: Kysely<unknown>): Promise<void> {
  await sql.raw('DROP SCHEMA media CASCADE').execute(db);
}
