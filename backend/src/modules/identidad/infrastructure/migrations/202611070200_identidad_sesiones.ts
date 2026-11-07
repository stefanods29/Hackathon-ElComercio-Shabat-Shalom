import { type Kysely, sql } from 'kysely';

/** Refresh hashes and session families are private: never published to PowerSync. */
export async function up(db: Kysely<unknown>): Promise<void> {
  await sql
    .raw(
      `
CREATE TABLE identidad.sesiones (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  usuario_id uuid NOT NULL REFERENCES identidad.usuarios(id),
  familia_id uuid NOT NULL,
  refresh_hash text NOT NULL UNIQUE,
  dispositivo text CHECK (char_length(dispositivo) <= 80),
  creada_en timestamptz NOT NULL DEFAULT now(),
  expira_en timestamptz NOT NULL,
  rotada_en timestamptz,
  revocada_en timestamptz,
  motivo text CHECK (motivo IN ('cierre', 'revocacion_total', 'reutilizacion'))
);
CREATE INDEX sesiones_usuario_activas_idx ON identidad.sesiones (usuario_id) WHERE revocada_en IS NULL;
CREATE INDEX sesiones_familia_idx ON identidad.sesiones (familia_id);
`,
    )
    .execute(db);
}

export async function down(db: Kysely<unknown>): Promise<void> {
  await sql.raw('DROP TABLE identidad.sesiones;').execute(db);
}
