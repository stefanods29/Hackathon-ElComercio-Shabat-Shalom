import { type Kysely, sql } from 'kysely';

/**
 * Base común: extensiones, compatibilidad de `uuidv7()`, esquema `compartido` (idempotencia y
 * outbox) y la publicación `powersync` vacía. Cada módulo agrega a la publicación solo las
 * tablas que deben llegar a los celulares (minimización de datos).
 */
export async function up(db: Kysely<unknown>): Promise<void> {
  await sql
    .raw(
      `
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;

-- uuidv7() es nativa en PostgreSQL 18. En versiones anteriores (solo desarrollo) se define
-- una equivalente; en PostgreSQL 18 este bloque no hace nada.
DO $bloque$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE p.proname = 'uuidv7' AND n.nspname = 'pg_catalog'
  ) THEN
    CREATE OR REPLACE FUNCTION public.uuidv7() RETURNS uuid
    LANGUAGE sql VOLATILE AS $funcion$
      SELECT encode(
        set_bit(
          set_bit(
            overlay(uuid_send(gen_random_uuid())
              PLACING substring(int8send(floor(extract(epoch FROM clock_timestamp()) * 1000)::bigint) FROM 3)
              FROM 1 FOR 6),
            52, 1),
          53, 1),
        'hex')::uuid
    $funcion$;
  END IF;
END
$bloque$;

CREATE SCHEMA IF NOT EXISTS compartido;

CREATE TABLE compartido.idempotencia (
  alcance           text        NOT NULL,
  clave             text        NOT NULL CHECK (char_length(clave) BETWEEN 8 AND 255),
  metodo            text        NOT NULL,
  ruta              text        NOT NULL,
  huella            text        NOT NULL,
  estado            text        NOT NULL CHECK (estado IN ('en_curso', 'completada')),
  codigo_http       smallint,
  cuerpo_respuesta  jsonb,
  creada_en         timestamptz NOT NULL DEFAULT now(),
  expira_en         timestamptz NOT NULL,
  PRIMARY KEY (alcance, clave)
);
CREATE INDEX idempotencia_expira_idx ON compartido.idempotencia (expira_en);

CREATE TABLE compartido.outbox (
  id            uuid        PRIMARY KEY DEFAULT uuidv7(),
  modulo        text        NOT NULL,
  tipo          text        NOT NULL,
  agregado_id   uuid        NOT NULL,
  carga         jsonb       NOT NULL,
  ocurrido_en   timestamptz NOT NULL DEFAULT now(),
  publicado_en  timestamptz,
  intentos      int         NOT NULL DEFAULT 0
);
CREATE INDEX outbox_pendientes_idx ON compartido.outbox (ocurrido_en) WHERE publicado_en IS NULL;

DO $bloque$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'powersync') THEN
    CREATE PUBLICATION powersync;
  END IF;
END
$bloque$;
`,
    )
    .execute(db);
}

export async function down(db: Kysely<unknown>): Promise<void> {
  await sql
    .raw(
      `
DROP PUBLICATION IF EXISTS powersync;
DROP TABLE IF EXISTS compartido.outbox;
DROP TABLE IF EXISTS compartido.idempotencia;
`,
    )
    .execute(db);
}
