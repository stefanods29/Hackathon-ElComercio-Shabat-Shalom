import { type Kysely, sql } from 'kysely';

export async function up(db: Kysely<unknown>): Promise<void> {
  await sql
    .raw(
      `
    -- Phase 2, Lot C: every version of the emergency directory published from the console.
    CREATE SCHEMA curaduria;
    CREATE TABLE curaduria.versiones_directorio (
      archivo text NOT NULL CHECK (archivo ~ '^[a-z0-9-]{2,60}\\.json$'),
      version integer NOT NULL CHECK (version >= 1),
      contenido jsonb NOT NULL,
      sha256 text NOT NULL CHECK (sha256 ~ '^[0-9a-f]{64}$'),
      bytes integer NOT NULL CHECK (bytes BETWEEN 1 AND 1048576),
      -- No foreign key: the audit survives even if the curator's account is later deleted.
      publicado_por uuid NOT NULL,
      publicado_en timestamptz NOT NULL DEFAULT now(),
      PRIMARY KEY (archivo, version)
    );
    -- Deliberately excluded from the PowerSync publication: phones read the CDN copy instead.
  `,
    )
    .execute(db);
}

export async function down(db: Kysely<unknown>): Promise<void> {
  await sql.raw('DROP SCHEMA curaduria CASCADE').execute(db);
}
