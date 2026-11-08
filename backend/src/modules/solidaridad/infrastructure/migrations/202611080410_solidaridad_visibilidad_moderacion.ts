import { type Kysely, sql } from 'kysely';

export async function up(db: Kysely<unknown>): Promise<void> {
  await sql
    .raw('ALTER TABLE solidaridad.publicaciones ADD COLUMN oculta_en timestamptz')
    .execute(db);
}

export async function down(db: Kysely<unknown>): Promise<void> {
  await sql.raw('ALTER TABLE solidaridad.publicaciones DROP COLUMN oculta_en').execute(db);
}
