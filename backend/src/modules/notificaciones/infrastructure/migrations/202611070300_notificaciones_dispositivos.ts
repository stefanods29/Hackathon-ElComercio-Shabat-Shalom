import { type Kysely, sql } from 'kysely';

export async function up(db: Kysely<unknown>): Promise<void> {
  await sql
    .raw(
      `
    CREATE SCHEMA notificaciones;
    CREATE TABLE notificaciones.dispositivos (
      id uuid PRIMARY KEY DEFAULT uuidv7(),
      usuario_id uuid NOT NULL REFERENCES identidad.usuarios(id),
      token text NOT NULL CHECK (char_length(token) BETWEEN 1 AND 4096 AND token ~ '^[!-~]+$'),
      -- A 4096-byte token exceeds PostgreSQL's btree entry limit; index its SHA-256 instead.
      token_hash bytea NOT NULL UNIQUE CHECK (token_hash = sha256(convert_to(token, 'UTF8'))),
      plataforma text NOT NULL CHECK (plataforma IN ('android', 'ios')),
      creado_en timestamptz NOT NULL DEFAULT now(),
      actualizado_en timestamptz NOT NULL DEFAULT now(),
      dado_de_baja_en timestamptz
    );
    CREATE INDEX dispositivos_usuario_idx ON notificaciones.dispositivos (usuario_id)
      WHERE dado_de_baja_en IS NULL;
    CREATE TABLE notificaciones.avisos_enviados (
      aviso_id uuid PRIMARY KEY,
      huella text NOT NULL,
      plantilla text NOT NULL,
      estado text NOT NULL CHECK (estado IN ('enviando', 'enviado')),
      creado_en timestamptz NOT NULL DEFAULT now()
    );
    CREATE TABLE notificaciones.entregas_aviso (
      aviso_id uuid NOT NULL REFERENCES notificaciones.avisos_enviados(aviso_id),
      destinatario text NOT NULL,
      usuario_id uuid,
      estado text NOT NULL DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'enviado', 'omitido')),
      PRIMARY KEY (aviso_id, destinatario)
    );
    -- Deliberately excluded from the PowerSync publication: tokens stay on the server.
  `,
    )
    .execute(db);
}

export async function down(db: Kysely<unknown>): Promise<void> {
  await sql.raw('DROP SCHEMA notificaciones CASCADE').execute(db);
}
