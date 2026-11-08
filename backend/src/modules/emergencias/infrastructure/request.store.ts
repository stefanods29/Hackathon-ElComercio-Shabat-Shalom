import { Injectable } from '@nestjs/common';
import { sql } from 'kysely';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import { asKysely } from '../../../shared/db/unit-of-work.kysely.js';
import type { RequestHistory, RequestStore, StreamAccess } from '../application/ports.js';
import type { Assignment, HelpRequest, PrivateRequestDetails } from '../domain/emergency.js';

const fields = sql.raw(`id,evento_id AS "eventId",zona_id AS "zoneId",autor_id AS "ownerId",
  necesidad AS need,prioridad AS priority,estado AS state,version,celda AS cell,
  creado_en AS "createdAt",vence_en AS "expiresAt",visto_en AS "seenAt",cerrado_en AS "closedAt",
  escalar_en AS "escalateAt",etapa_escalamiento AS "escalationStage",huella AS fingerprint,
  anonimizado_en AS "anonymizedAt"`);

@Injectable()
export class PostgresRequestStore implements RequestStore {
  async removePrivate(tx: TransactionContext, id: string): Promise<void> {
    await sql`DELETE FROM emergencias.detalles_pedidos WHERE pedido_id = ${id}`.execute(
      asKysely(tx),
    );
    await sql`UPDATE emergencias.historial_pedidos SET motivo = NULL WHERE pedido_id = ${id}`.execute(
      asKysely(tx),
    );
  }
  async find(tx: TransactionContext, id: string): Promise<HelpRequest | null> {
    await sql`SELECT pg_advisory_xact_lock(hashtextextended(${`pedido:${id}`},0))`.execute(
      asKysely(tx),
    );
    const result = await sql<HelpRequest>`SELECT ${fields} FROM emergencias.pedidos_ayuda
      WHERE id = ${id} AND evento_id IS NOT NULL FOR UPDATE`.execute(asKysely(tx));
    return result.rows[0] ?? null;
  }
  async insert(
    tx: TransactionContext,
    request: HelpRequest,
    details: PrivateRequestDetails,
  ): Promise<void> {
    await sql`INSERT INTO emergencias.pedidos_ayuda(id,evento_id,zona_id,autor_id,necesidad,prioridad,
      estado,celda,creado_en,vence_en,escalar_en,huella,detalle)
      VALUES(${request.id},${request.eventId},${request.zoneId},${request.ownerId},${request.need},
      ${request.priority},'enviado',${request.cell},${request.createdAt},${request.expiresAt},
      ${request.escalateAt},${request.fingerprint},'Solicitud de apoyo vecinal')`.execute(
      asKysely(tx),
    );
    await sql`INSERT INTO emergencias.detalles_pedidos(pedido_id,descripcion,lat,lng)
      VALUES(${request.id},${details.description},${details.location?.lat ?? null},${details.location?.lng ?? null})`.execute(
      asKysely(tx),
    );
  }
  async list(
    tx: TransactionContext,
    filter: {
      ownerId?: string;
      zoneId?: string;
      operatorId?: string;
      now: Date;
      cursor?: string;
      limit: number;
    },
  ): Promise<HelpRequest[]> {
    const conditions = [sql`evento_id IS NOT NULL`, sql`anonimizado_en IS NULL`];
    if (filter.ownerId) conditions.push(sql`autor_id = ${filter.ownerId}`);
    if (filter.zoneId)
      conditions.push(sql`cerrado_en IS NULL AND vence_en > ${filter.now} AND (zona_id = ${filter.zoneId}
      OR id IN (SELECT pedido_id FROM emergencias.asignaciones WHERE usuario_id = ${filter.operatorId ?? null}
        AND finalizada_en IS NULL AND acceso_hasta > ${filter.now}))`);
    if (filter.cursor) conditions.push(sql`id > ${filter.cursor}::uuid`);
    return (
      await sql<HelpRequest>`SELECT ${fields} FROM emergencias.pedidos_ayuda
      WHERE ${sql.join(conditions, sql` AND `)} ORDER BY id LIMIT ${filter.limit}`.execute(
        asKysely(tx),
      )
    ).rows;
  }
  async details(tx: TransactionContext, id: string): Promise<PrivateRequestDetails | null> {
    const row = (
      await sql<{
        description: string;
        lat: number | null;
        lng: number | null;
      }>`SELECT descripcion AS description,lat,lng
      FROM emergencias.detalles_pedidos WHERE pedido_id = ${id}`.execute(asKysely(tx))
    ).rows[0];
    return row
      ? {
          description: row.description,
          location: row.lat === null || row.lng === null ? null : { lat: row.lat, lng: row.lng },
        }
      : null;
  }
  async assignments(tx: TransactionContext, id: string, now: Date): Promise<Assignment[]> {
    return (
      await sql<Assignment>`SELECT id,pedido_id AS "requestId",usuario_id AS "userId",rol AS role,
      acceso_hasta AS "expiresAt" FROM emergencias.asignaciones WHERE pedido_id = ${id}
      AND finalizada_en IS NULL AND acceso_hasta > ${now} ORDER BY rol`.execute(asKysely(tx))
    ).rows;
  }
  async assign(tx: TransactionContext, assignment: Assignment, now: Date): Promise<void> {
    await sql`UPDATE emergencias.asignaciones SET finalizada_en = ${now}
      WHERE pedido_id = ${assignment.requestId} AND rol = ${assignment.role} AND finalizada_en IS NULL`.execute(
      asKysely(tx),
    );
    await sql`INSERT INTO emergencias.asignaciones(id,pedido_id,usuario_id,rol,asignada_en,acceso_hasta)
      VALUES(${assignment.id},${assignment.requestId},${assignment.userId},${assignment.role},${now},${assignment.expiresAt})`.execute(
      asKysely(tx),
    );
  }
  async history(tx: TransactionContext, id: string): Promise<RequestHistory[]> {
    return (
      await sql<RequestHistory>`SELECT desde AS "from",hasta AS "to",rol AS role,
      ocurrido_en AS at,motivo AS reason FROM emergencias.historial_pedidos WHERE pedido_id = ${id}
      ORDER BY id LIMIT 200`.execute(asKysely(tx))
    ).rows;
  }
  async addHistory(
    tx: TransactionContext,
    id: string,
    entry: RequestHistory,
    actorId: string | null,
  ): Promise<void> {
    await sql`INSERT INTO emergencias.historial_pedidos(pedido_id,desde,hasta,usuario_id,rol,ocurrido_en,motivo)
      VALUES(${id},${entry.from},${entry.to},${actorId},${entry.role},${entry.at},${entry.reason})`.execute(
      asKysely(tx),
    );
  }
  async update(tx: TransactionContext, request: HelpRequest): Promise<void> {
    await sql`UPDATE emergencias.pedidos_ayuda SET estado = ${request.state},prioridad = ${request.priority},version = ${request.version},
      visto_en = ${request.seenAt},cerrado_en = ${request.closedAt},escalar_en = ${request.escalateAt},
      etapa_escalamiento = ${request.escalationStage} WHERE id = ${request.id}`.execute(
      asKysely(tx),
    );
    if (request.closedAt)
      await sql`UPDATE emergencias.asignaciones SET finalizada_en = ${request.closedAt}
      WHERE pedido_id = ${request.id} AND finalizada_en IS NULL`.execute(asKysely(tx));
  }
  async due(tx: TransactionContext, now: Date): Promise<string[]> {
    return (
      await sql<{ id: string }>`SELECT id FROM emergencias.pedidos_ayuda WHERE estado = 'enviado'
      AND escalar_en <= ${now} AND vence_en > ${now} AND anonimizado_en IS NULL
      ORDER BY escalar_en,id LIMIT 100`.execute(asKysely(tx))
    ).rows.map((row) => row.id);
  }
  async expired(tx: TransactionContext, now: Date): Promise<string[]> {
    return (
      await sql<{ id: string }>`SELECT p.id FROM emergencias.pedidos_ayuda p WHERE
      (p.cerrado_en IS NULL OR EXISTS(SELECT 1 FROM emergencias.detalles_pedidos d WHERE d.pedido_id = p.id))
      AND p.evento_id IS NOT NULL AND p.vence_en <= ${now} ORDER BY p.vence_en,p.id LIMIT 100`.execute(
        asKysely(tx),
      )
    ).rows.map((row) => row.id);
  }
  async wasEscalatedTo(tx: TransactionContext, id: string, userId: string): Promise<boolean> {
    return (
      (
        await sql`SELECT 1 FROM emergencias.escalamientos WHERE pedido_id = ${id}
      AND usuario_id = ${userId} LIMIT 1`.execute(asKysely(tx))
      ).rows.length > 0
    );
  }
  async openStreamAccess(tx: TransactionContext, access: StreamAccess): Promise<StreamAccess> {
    const row = (
      await sql<{ id: string; expiresAt: Date }>`INSERT INTO emergencias.autorizaciones_stream
      (id,asignacion_id,pedido_id,usuario_id,sesion_id,alcance,creada_en,vence_en)
      VALUES(${access.id},${access.assignmentId},${access.requestId},${access.userId},
      ${access.sessionId},${access.scope},${access.createdAt},${access.expiresAt})
      ON CONFLICT (asignacion_id,sesion_id,alcance) WHERE revocada_en IS NULL
      DO UPDATE SET vence_en = EXCLUDED.vence_en
      RETURNING id,vence_en AS "expiresAt"`.execute(asKysely(tx))
    ).rows[0]!;
    return { ...access, id: row.id, expiresAt: row.expiresAt };
  }
  async recordEscalation(
    tx: TransactionContext,
    request: HelpRequest,
    userId: string | null,
    now: Date,
  ): Promise<void> {
    await sql`INSERT INTO emergencias.escalamientos(pedido_id,etapa,usuario_id,ocurrido_en)
      VALUES(${request.id},${request.escalationStage},${userId},${now}) ON CONFLICT DO NOTHING`.execute(
      asKysely(tx),
    );
  }
}
