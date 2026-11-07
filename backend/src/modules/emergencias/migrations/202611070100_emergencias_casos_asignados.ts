import { type Kysely, sql } from 'kysely';

export async function up(db: Kysely<unknown>): Promise<void> {
  await sql`
    CREATE SCHEMA IF NOT EXISTS emergencias;

    CREATE TABLE emergencias.pedidos_ayuda (
      id              uuid PRIMARY KEY DEFAULT uuidv7(),
      detalle         text NOT NULL CHECK (char_length(detalle) BETWEEN 1 AND 2000),
      creado_en       timestamptz NOT NULL DEFAULT now(),
      vence_en        timestamptz NOT NULL,
      cerrado_en      timestamptz,
      CHECK (vence_en > creado_en)
    );

    CREATE TABLE emergencias.asignaciones (
      id              uuid PRIMARY KEY DEFAULT uuidv7(),
      pedido_id       uuid NOT NULL REFERENCES emergencias.pedidos_ayuda(id),
      usuario_id      uuid NOT NULL REFERENCES identidad.usuarios(id),
      asignada_en     timestamptz NOT NULL DEFAULT now(),
      finalizada_en   timestamptz,
      CHECK (finalizada_en IS NULL OR finalizada_en >= asignada_en)
    );
    CREATE UNIQUE INDEX asignaciones_pedido_activo_idx
      ON emergencias.asignaciones (pedido_id) WHERE finalizada_en IS NULL;

    ALTER PUBLICATION powersync ADD TABLE emergencias.pedidos_ayuda, emergencias.asignaciones;
    DO $bloque$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'powersync_rol') THEN
        GRANT USAGE ON SCHEMA emergencias TO powersync_rol;
        GRANT SELECT ON emergencias.pedidos_ayuda, emergencias.asignaciones TO powersync_rol;
      END IF;
    END
    $bloque$;
  `.execute(db);
}

export async function down(db: Kysely<unknown>): Promise<void> {
  await sql`
    ALTER PUBLICATION powersync DROP TABLE emergencias.pedidos_ayuda, emergencias.asignaciones;
    DROP TABLE emergencias.asignaciones;
    DROP TABLE emergencias.pedidos_ayuda;
    DROP SCHEMA emergencias;
  `.execute(db);
}
