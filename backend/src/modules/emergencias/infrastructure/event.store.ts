import { Injectable } from '@nestjs/common';
import { sql } from 'kysely';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import { asJsonb, asKysely } from '../../../shared/db/unit-of-work.kysely.js';
import type { EventStore } from '../application/ports.js';
import type { EmergencyEvent } from '../domain/emergency.js';

const fields = sql.raw(`id, zona_id AS "zoneId", nivel AS level, estado AS state, version,
  activado_en AS "createdAt", cerrado_en AS "closedAt", fuente AS source,
  referencia_externa AS "externalId", resumen AS summary`);

@Injectable()
export class PostgresEventStore implements EventStore {
  async lockZone(tx: TransactionContext, zoneId: string): Promise<void> {
    await sql`SELECT pg_advisory_xact_lock(hashtextextended(${`emergencias:${zoneId}`},0))`.execute(
      asKysely(tx),
    );
  }
  async find(tx: TransactionContext, id: string): Promise<EmergencyEvent | null> {
    const result =
      await sql<EmergencyEvent>`SELECT ${fields} FROM emergencias.eventos WHERE id = ${id}`.execute(
        asKysely(tx),
      );
    return result.rows[0] ?? null;
  }
  async current(tx: TransactionContext, zoneId: string): Promise<EmergencyEvent | null> {
    const result = await sql<EmergencyEvent>`SELECT ${fields} FROM emergencias.eventos
      WHERE zona_id = ${zoneId} AND estado <> 'normal'`.execute(asKysely(tx));
    return result.rows[0] ?? null;
  }
  async list(tx: TransactionContext, zoneId: string): Promise<EmergencyEvent[]> {
    return (
      await sql<EmergencyEvent>`SELECT ${fields} FROM emergencias.eventos
      WHERE zona_id = ${zoneId} ORDER BY activado_en DESC,id LIMIT 100`.execute(asKysely(tx))
    ).rows;
  }
  async insert(
    tx: TransactionContext,
    event: EmergencyEvent,
    actorId: string | null,
  ): Promise<void> {
    await sql`INSERT INTO emergencias.eventos(id,zona_id,nivel,estado,activado_por,activado_en,fuente,referencia_externa)
      VALUES(${event.id},${event.zoneId},${event.level},${event.state},${actorId},${event.createdAt},${event.source},${event.externalId})`.execute(
      asKysely(tx),
    );
  }
  async close(
    tx: TransactionContext,
    event: EmergencyEvent,
    now: Date,
    reason: string,
  ): Promise<EmergencyEvent> {
    const counts = await sql<{ state: string; need: string; count: number }>`SELECT estado AS state,
      necesidad AS need, count(*)::int AS count FROM emergencias.pedidos_ayuda
      WHERE evento_id = ${event.id} GROUP BY estado,necesidad`.execute(asKysely(tx));
    const summary = {
      total: counts.rows.reduce((sum, row) => sum + row.count, 0),
      categorias: counts.rows.map((row) => ({
        estado: row.state,
        necesidad: row.need,
        cantidad: row.count,
      })),
      cierreSolicitadoEn: now.toISOString(),
    };
    await sql`UPDATE emergencias.eventos SET estado = 'recuperacion', version = version + 1,
      resumen = ${asJsonb(summary)}, motivo_cierre = ${reason} WHERE id = ${event.id}`.execute(
      asKysely(tx),
    );
    await sql`UPDATE emergencias.asignaciones a SET finalizada_en = ${now}
      FROM emergencias.pedidos_ayuda p WHERE p.id = a.pedido_id AND p.evento_id = ${event.id}
      AND a.finalizada_en IS NULL`.execute(asKysely(tx));
    return { ...event, state: 'recuperacion', version: event.version + 1, summary };
  }
  async closing(tx: TransactionContext): Promise<string[]> {
    return (
      await sql<{ id: string }>`SELECT id FROM emergencias.eventos WHERE estado = 'recuperacion'
      ORDER BY id LIMIT 20`.execute(asKysely(tx))
    ).rows.map((row) => row.id);
  }
  async anonymizeBatch(tx: TransactionContext, eventId: string, now: Date): Promise<boolean> {
    const batch = await sql<{ id: string }>`SELECT id FROM emergencias.pedidos_ayuda
      WHERE evento_id = ${eventId} AND anonimizado_en IS NULL ORDER BY id LIMIT 100 FOR UPDATE SKIP LOCKED`.execute(
      asKysely(tx),
    );
    for (const { id } of batch.rows) {
      await sql`INSERT INTO emergencias.historial_pedidos(pedido_id,desde,hasta,rol,ocurrido_en,motivo)
        SELECT id,estado,'cerrado_sin_atender','sistema',${now},'Cierre del evento'
        FROM emergencias.pedidos_ayuda WHERE id = ${id} AND cerrado_en IS NULL`.execute(
        asKysely(tx),
      );
      await sql`UPDATE emergencias.pedidos_ayuda SET autor_id = NULL, huella = NULL,
        detalle = 'Pedido anonimizado', celda = NULL, escalar_en = NULL, anonimizado_en = ${now},
        estado = CASE WHEN cerrado_en IS NULL THEN 'cerrado_sin_atender' ELSE estado END,
        cerrado_en = coalesce(cerrado_en,${now}), version = version + 1 WHERE id = ${id}`.execute(
        asKysely(tx),
      );
      await sql`DELETE FROM emergencias.detalles_pedidos WHERE pedido_id = ${id}`.execute(
        asKysely(tx),
      );
      await sql`UPDATE emergencias.historial_pedidos SET usuario_id = NULL,motivo = NULL WHERE pedido_id = ${id}`.execute(
        asKysely(tx),
      );
      await sql`DELETE FROM emergencias.asignaciones WHERE pedido_id = ${id}`.execute(asKysely(tx));
      await sql`UPDATE emergencias.escalamientos SET usuario_id = NULL WHERE pedido_id = ${id}`.execute(
        asKysely(tx),
      );
    }
    if (batch.rows.length === 100) return false;
    // A transaction holding another batch must finish before the event is declared closed.
    const remaining = await sql`SELECT id FROM emergencias.pedidos_ayuda
      WHERE evento_id = ${eventId} AND anonimizado_en IS NULL LIMIT 1`.execute(asKysely(tx));
    if (remaining.rows.length) return false;
    await sql`UPDATE emergencias.eventos SET estado = 'normal', cerrado_en = ${now},
      version = version + 1 WHERE id = ${eventId} AND estado = 'recuperacion'`.execute(
      asKysely(tx),
    );
    return true;
  }
  async processedAlert(tx: TransactionContext, reference: string, now: Date): Promise<boolean> {
    const result = await sql`INSERT INTO emergencias.alertas_recibidas(referencia,procesada_en)
      VALUES(${reference},${now}) ON CONFLICT DO NOTHING RETURNING referencia`.execute(
      asKysely(tx),
    );
    return result.rows.length === 1;
  }
}
