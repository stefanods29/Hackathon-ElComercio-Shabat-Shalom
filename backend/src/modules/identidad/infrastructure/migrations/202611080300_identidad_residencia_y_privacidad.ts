import { type Kysely, sql } from 'kysely';

export async function up(db: Kysely<unknown>): Promise<void> {
  await sql
    .raw(
      `
    ALTER TABLE identidad.usuarios
      ADD COLUMN zona_elegida_en timestamptz,
      ALTER COLUMN telefono DROP NOT NULL,
      ADD CONSTRAINT usuarios_telefono_activo_chk
        CHECK (eliminado_en IS NOT NULL OR telefono IS NOT NULL);

    UPDATE identidad.usuarios SET zona_elegida_en = actualizado_en WHERE zona_id IS NOT NULL;

    CREATE TABLE identidad.consentimientos (
      id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      usuario_id uuid NOT NULL REFERENCES identidad.usuarios(id),
      finalidad text NOT NULL CHECK (finalidad IN ('uso_del_servicio', 'confirmacion_por_presencia')),
      version int NOT NULL CHECK (version > 0),
      aceptado boolean NOT NULL,
      decidido_en timestamptz NOT NULL
    );
    CREATE INDEX consentimientos_usuario_finalidad_idx
      ON identidad.consentimientos (usuario_id, finalidad, id DESC);

    CREATE TABLE identidad.presencias (
      usuario_id uuid NOT NULL REFERENCES identidad.usuarios(id),
      fecha date NOT NULL,
      dentro_de_la_zona boolean NOT NULL,
      PRIMARY KEY (usuario_id, fecha)
    );
    CREATE INDEX presencias_fecha_idx ON identidad.presencias (fecha);

    CREATE TABLE identidad.avales (
      vecino_id uuid NOT NULL REFERENCES identidad.usuarios(id),
      avalista_id uuid NOT NULL REFERENCES identidad.usuarios(id),
      zona_id uuid NOT NULL REFERENCES identidad.zonas(id),
      creado_en timestamptz NOT NULL,
      PRIMARY KEY (vecino_id, avalista_id),
      CHECK (vecino_id <> avalista_id)
    );
    CREATE INDEX avales_avalista_idx ON identidad.avales (avalista_id);

    CREATE TABLE identidad.confirmaciones (
      id uuid PRIMARY KEY DEFAULT uuidv7(),
      vecino_id uuid NOT NULL REFERENCES identidad.usuarios(id),
      moderador_id uuid NOT NULL REFERENCES identidad.usuarios(id),
      zona_id uuid NOT NULL REFERENCES identidad.zonas(id),
      motivo text NOT NULL CHECK (char_length(motivo) BETWEEN 1 AND 500),
      nivel smallint NOT NULL CHECK (nivel IN (1, 2)),
      creada_en timestamptz NOT NULL
    );
    CREATE INDEX confirmaciones_vecino_idx ON identidad.confirmaciones (vecino_id);
    CREATE INDEX confirmaciones_moderador_idx ON identidad.confirmaciones (moderador_id);
  `,
    )
    .execute(db);
}

export async function down(db: Kysely<unknown>): Promise<void> {
  await sql
    .raw(
      `
    DROP TABLE identidad.confirmaciones;
    DROP TABLE identidad.avales;
    DROP TABLE identidad.presencias;
    DROP TABLE identidad.consentimientos;

    -- Restoring the legacy NOT NULL must not recover erased numbers or collide with live ones.
    WITH tombstones AS (
      SELECT id, row_number() OVER (ORDER BY id) AS n
      FROM identidad.usuarios WHERE telefono IS NULL
    ), candidates AS (
      SELECT candidate.telefono, row_number() OVER (ORDER BY serial.n) AS n
      FROM generate_series(1, (SELECT count(*) FROM identidad.usuarios)) AS serial(n)
      CROSS JOIN LATERAL (SELECT '+999' || lpad(serial.n::text, 12, '0') AS telefono) AS candidate
      WHERE NOT EXISTS (
        SELECT 1 FROM identidad.usuarios AS u WHERE u.telefono = candidate.telefono
      )
    )
    UPDATE identidad.usuarios AS u SET telefono = c.telefono
    FROM tombstones AS t JOIN candidates AS c USING (n)
    WHERE u.id = t.id;

    ALTER TABLE identidad.usuarios
      DROP CONSTRAINT usuarios_telefono_activo_chk,
      ALTER COLUMN telefono SET NOT NULL,
      DROP COLUMN zona_elegida_en;
  `,
    )
    .execute(db);
}
