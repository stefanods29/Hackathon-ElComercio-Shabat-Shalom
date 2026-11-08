import { type Kysely, sql } from 'kysely';

export async function up(db: Kysely<unknown>): Promise<void> {
  await sql
    .raw(
      `
CREATE SCHEMA moderacion;
CREATE TABLE moderacion.casos (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  tipo_contenido text NOT NULL,
  contenido_id uuid NOT NULL,
  estado text NOT NULL DEFAULT 'pendiente',
  motivo text NOT NULL,
  creado_en timestamptz NOT NULL DEFAULT now(),
  actualizado_en timestamptz NOT NULL DEFAULT now(),
  primera_revision_en timestamptz,
  UNIQUE (tipo_contenido, contenido_id)
);
CREATE INDEX casos_estado_fecha_idx ON moderacion.casos (estado, creado_en, id);
  `,
    )
    .execute(db);
}

export async function down(db: Kysely<unknown>): Promise<void> {
  await sql.raw('DROP TABLE moderacion.casos; DROP SCHEMA moderacion;').execute(db);
}
