import { type Kysely, sql } from 'kysely';

export async function up(db: Kysely<unknown>): Promise<void> {
  await sql
    .raw(
      `
CREATE TABLE identidad.codigos_otp (
  id           uuid        PRIMARY KEY DEFAULT uuidv7(),
  telefono     text        NOT NULL CHECK (telefono ~ '^\\+[1-9][0-9]{7,14}$'),
  codigo_hash  text        NOT NULL,
  canal        text        NOT NULL CHECK (canal IN ('sms', 'whatsapp')),
  ip           inet,
  intentos     smallint    NOT NULL DEFAULT 0,
  expira_en    timestamptz NOT NULL,
  usado_en     timestamptz,
  creado_en    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX codigos_otp_telefono_idx ON identidad.codigos_otp (telefono, creado_en DESC);
CREATE INDEX codigos_otp_ip_idx ON identidad.codigos_otp (ip, creado_en DESC);
`,
    )
    .execute(db);
}

export async function down(db: Kysely<unknown>): Promise<void> {
  await sql.raw('DROP TABLE identidad.codigos_otp;').execute(db);
}
