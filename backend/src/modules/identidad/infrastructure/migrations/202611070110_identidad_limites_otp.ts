import { type Kysely, sql } from 'kysely';

/** Private abuse-control state: deliberately excluded from PowerSync. */
export async function up(db: Kysely<unknown>): Promise<void> {
  await sql
    .raw(
      `
CREATE TABLE identidad.limites_otp (
  ambito text NOT NULL CHECK (ambito IN ('telefono', 'ip')),
  identificador text NOT NULL,
  intentos integer NOT NULL CHECK (intentos >= 0),
  ventana_desde timestamptz NOT NULL,
  bloqueado_hasta timestamptz,
  PRIMARY KEY (ambito, identificador)
);
`,
    )
    .execute(db);
}

export async function down(db: Kysely<unknown>): Promise<void> {
  await sql.raw('DROP TABLE identidad.limites_otp;').execute(db);
}
