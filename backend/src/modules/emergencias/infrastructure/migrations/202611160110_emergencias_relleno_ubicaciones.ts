import { type Kysely, sql } from 'kysely';

/** Repairs cases that were already on the way when the projection trigger was installed. */
export async function up(db: Kysely<unknown>): Promise<void> {
  await sql`
    INSERT INTO emergencias.ubicaciones_en_camino (pedido_id, descripcion, lat, lng, actualizado_en)
    SELECT p.id, d.descripcion, d.lat, d.lng, statement_timestamp()
    FROM emergencias.pedidos_ayuda p
    JOIN emergencias.detalles_pedidos d ON d.pedido_id = p.id
    WHERE p.estado = 'en_camino'
      AND p.cerrado_en IS NULL
      AND p.anonimizado_en IS NULL
      AND p.vence_en > statement_timestamp()
    ORDER BY p.id
    FOR UPDATE OF p
    ON CONFLICT (pedido_id) DO NOTHING
  `.execute(db);
}

/** The rows now belong to the live projection. Its own migration owns removal of the table. */
export function down(): Promise<void> {
  return Promise.resolve();
}
