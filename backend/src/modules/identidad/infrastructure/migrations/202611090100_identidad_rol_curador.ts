import { type Kysely, sql } from 'kysely';

export async function up(db: Kysely<unknown>): Promise<void> {
  await sql`ALTER TABLE identidad.usuarios DROP CONSTRAINT usuarios_roles_check;
    ALTER TABLE identidad.usuarios ADD CONSTRAINT usuarios_roles_check CHECK (
      roles <@ ARRAY['proveedor','moderador','coordinador','brigadista','curador','administrador']::text[]
    );`.execute(db);
}
export async function down(): Promise<void> {
  throw new Error(
    'Revisar las habilitaciones antes de retirar el rol curador; no se revocan accesos automáticamente.',
  );
}
