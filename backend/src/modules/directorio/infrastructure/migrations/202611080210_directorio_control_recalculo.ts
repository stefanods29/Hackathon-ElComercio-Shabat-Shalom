import { type Kysely, sql } from 'kysely';

export async function up(db: Kysely<unknown>): Promise<void> {
  await sql
    .raw(
      `
CREATE TABLE directorio.recalculos_reputacion (
  servicio_id uuid PRIMARY KEY REFERENCES directorio.servicios(id) ON DELETE CASCADE,
  evento_id uuid NOT NULL,
  ocurrido_en timestamptz NOT NULL
);
  `,
    )
    .execute(db);
}

export async function down(db: Kysely<unknown>): Promise<void> {
  await sql.raw('DROP TABLE directorio.recalculos_reputacion').execute(db);
}
