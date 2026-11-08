import { type Kysely, sql } from 'kysely';

/**
 * Phase 2 integration of Lots A and B: what the phone's on-demand streams need, without adding
 * private details to the PowerSync publication.
 *
 * - `historial_para_autor`: the requester's history (A, stream `mi_pedido`). It leaves out the
 *   operator and the operational reason; only referrals and closures keep a reason for the author.
 * - `ubicaciones_en_camino`: exact location and description only while the case is «En camino»
 *   (A, stream `caso_ubicacion_exacta`). `detalles_pedidos` stays out of the publication.
 * - `autorizaciones_stream`: audited permission tied to one assignment, session and scope
 *   (A, streams `caso_asignado` and `caso_ubicacion_exacta`).
 * - `verificado_en`: date of the human verification of a public resource (A, part 4).
 *
 * Triggers keep the copies in step with every path that changes a request (transitions, expiry,
 * event closure, account deletion), so none of them can leave a stale copy behind.
 */
export async function up(db: Kysely<unknown>): Promise<void> {
  await sql`
    CREATE TABLE emergencias.historial_para_autor (
      id bigint PRIMARY KEY REFERENCES emergencias.historial_pedidos(id) ON DELETE CASCADE,
      pedido_id uuid NOT NULL REFERENCES emergencias.pedidos_ayuda(id),
      desde text, hasta text NOT NULL, rol text NOT NULL, ocurrido_en timestamptz NOT NULL,
      motivo_para_autor text CHECK (char_length(motivo_para_autor) <= 500)
    );
    CREATE INDEX historial_para_autor_pedido_idx ON emergencias.historial_para_autor(pedido_id, id);

    CREATE FUNCTION emergencias.proyectar_historial_para_autor() RETURNS trigger
    LANGUAGE plpgsql AS $fn$
    BEGIN
      -- A change of priority keeps the state: it is operational, not news for the author.
      IF NEW.desde IS NOT DISTINCT FROM NEW.hasta THEN
        DELETE FROM emergencias.historial_para_autor WHERE id = NEW.id;
        RETURN NULL;
      END IF;
      INSERT INTO emergencias.historial_para_autor
        (id, pedido_id, desde, hasta, rol, ocurrido_en, motivo_para_autor)
      VALUES (NEW.id, NEW.pedido_id, NEW.desde, NEW.hasta, NEW.rol, NEW.ocurrido_en,
        CASE WHEN NEW.hasta IN ('derivado', 'cerrado_sin_atender') THEN NEW.motivo END)
      ON CONFLICT (id) DO UPDATE SET desde = EXCLUDED.desde, hasta = EXCLUDED.hasta,
        rol = EXCLUDED.rol, ocurrido_en = EXCLUDED.ocurrido_en,
        motivo_para_autor = EXCLUDED.motivo_para_autor;
      RETURN NULL;
    END $fn$;
    CREATE TRIGGER historial_para_autor_sync
      AFTER INSERT OR UPDATE ON emergencias.historial_pedidos
      FOR EACH ROW EXECUTE FUNCTION emergencias.proyectar_historial_para_autor();
    INSERT INTO emergencias.historial_para_autor
      (id, pedido_id, desde, hasta, rol, ocurrido_en, motivo_para_autor)
      SELECT id, pedido_id, desde, hasta, rol, ocurrido_en,
        CASE WHEN hasta IN ('derivado', 'cerrado_sin_atender') THEN motivo END
      FROM emergencias.historial_pedidos WHERE desde IS DISTINCT FROM hasta;

    CREATE TABLE emergencias.ubicaciones_en_camino (
      pedido_id uuid PRIMARY KEY
        REFERENCES emergencias.detalles_pedidos(pedido_id) ON DELETE CASCADE,
      descripcion text NOT NULL, lat double precision, lng double precision,
      actualizado_en timestamptz NOT NULL
    );
    CREATE FUNCTION emergencias.proyectar_ubicacion_en_camino() RETURNS trigger
    LANGUAGE plpgsql AS $fn$
    BEGIN
      IF NEW.estado = 'en_camino' AND NEW.cerrado_en IS NULL AND NEW.anonimizado_en IS NULL THEN
        INSERT INTO emergencias.ubicaciones_en_camino (pedido_id, descripcion, lat, lng, actualizado_en)
          SELECT pedido_id, descripcion, lat, lng, statement_timestamp()
          FROM emergencias.detalles_pedidos WHERE pedido_id = NEW.id
        ON CONFLICT (pedido_id) DO UPDATE SET descripcion = EXCLUDED.descripcion,
          lat = EXCLUDED.lat, lng = EXCLUDED.lng, actualizado_en = EXCLUDED.actualizado_en;
      ELSE
        DELETE FROM emergencias.ubicaciones_en_camino WHERE pedido_id = NEW.id;
      END IF;
      RETURN NULL;
    END $fn$;
    CREATE TRIGGER ubicacion_en_camino_sync
      AFTER INSERT OR UPDATE OF estado, cerrado_en, anonimizado_en ON emergencias.pedidos_ayuda
      FOR EACH ROW EXECUTE FUNCTION emergencias.proyectar_ubicacion_en_camino();

    CREATE TABLE emergencias.autorizaciones_stream (
      id uuid PRIMARY KEY,
      asignacion_id uuid NOT NULL REFERENCES emergencias.asignaciones(id) ON DELETE CASCADE,
      pedido_id uuid NOT NULL REFERENCES emergencias.pedidos_ayuda(id),
      usuario_id uuid NOT NULL REFERENCES identidad.usuarios(id),
      sesion_id uuid NOT NULL,
      alcance text NOT NULL CHECK (alcance IN ('resumen', 'exacta')),
      creada_en timestamptz NOT NULL, vence_en timestamptz NOT NULL, revocada_en timestamptz
    );
    CREATE UNIQUE INDEX autorizaciones_stream_vigente_idx
      ON emergencias.autorizaciones_stream(asignacion_id, sesion_id, alcance)
      WHERE revocada_en IS NULL;
    CREATE FUNCTION emergencias.revocar_autorizaciones_stream() RETURNS trigger
    LANGUAGE plpgsql AS $fn$
    BEGIN
      UPDATE emergencias.autorizaciones_stream SET revocada_en = NEW.finalizada_en
        WHERE asignacion_id = NEW.id AND revocada_en IS NULL;
      RETURN NULL;
    END $fn$;
    CREATE TRIGGER autorizaciones_stream_revocacion
      AFTER UPDATE OF finalizada_en ON emergencias.asignaciones
      FOR EACH ROW WHEN (NEW.finalizada_en IS NOT NULL AND OLD.finalizada_en IS NULL)
      EXECUTE FUNCTION emergencias.revocar_autorizaciones_stream();

    ALTER TABLE emergencias.recursos_criticos ADD COLUMN verificado_en timestamptz;
    ALTER TABLE emergencias.recursos_publicos ADD COLUMN verificado_en timestamptz;

    ALTER PUBLICATION powersync ADD TABLE emergencias.historial_para_autor,
      emergencias.ubicaciones_en_camino, emergencias.autorizaciones_stream;
    DO $block$ BEGIN
      IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'powersync_rol') THEN
        GRANT SELECT ON emergencias.historial_para_autor, emergencias.ubicaciones_en_camino,
          emergencias.autorizaciones_stream TO powersync_rol;
      END IF;
    END $block$;
  `.execute(db);
}

/** The copies are derived data: dropping them loses nothing that the source tables lack. */
export async function down(db: Kysely<unknown>): Promise<void> {
  await sql`
    ALTER PUBLICATION powersync DROP TABLE emergencias.historial_para_autor,
      emergencias.ubicaciones_en_camino, emergencias.autorizaciones_stream;
    ALTER TABLE emergencias.recursos_publicos DROP COLUMN verificado_en;
    ALTER TABLE emergencias.recursos_criticos DROP COLUMN verificado_en;
    DROP TRIGGER autorizaciones_stream_revocacion ON emergencias.asignaciones;
    DROP FUNCTION emergencias.revocar_autorizaciones_stream();
    DROP TABLE emergencias.autorizaciones_stream;
    DROP TRIGGER ubicacion_en_camino_sync ON emergencias.pedidos_ayuda;
    DROP FUNCTION emergencias.proyectar_ubicacion_en_camino();
    DROP TABLE emergencias.ubicaciones_en_camino;
    DROP TRIGGER historial_para_autor_sync ON emergencias.historial_pedidos;
    DROP FUNCTION emergencias.proyectar_historial_para_autor();
    DROP TABLE emergencias.historial_para_autor;
  `.execute(db);
}
