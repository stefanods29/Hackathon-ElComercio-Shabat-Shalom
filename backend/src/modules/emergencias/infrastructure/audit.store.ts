import { Injectable } from '@nestjs/common';
import { sql } from 'kysely';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import { asKysely } from '../../../shared/db/unit-of-work.kysely.js';
import type { AuditEntry, AuditStore } from '../application/ports.js';

@Injectable()
export class PostgresAuditStore implements AuditStore {
  async record(
    tx: TransactionContext,
    actorId: string | null,
    role: string,
    requestId: string | null,
    action: string,
    now: Date,
  ): Promise<void> {
    await sql`INSERT INTO emergencias.auditoria(usuario_id,rol,pedido_id,accion,ocurrido_en)
      VALUES(${actorId},${role},${requestId},${action},${now})`.execute(asKysely(tx));
  }
  async list(
    tx: TransactionContext,
    cursor: string | undefined,
    limit: number,
  ): Promise<AuditEntry[]> {
    return (
      await sql<AuditEntry>`SELECT id::text,usuario_id AS "userId",pedido_id AS "requestId",rol AS role,
      accion AS action,ocurrido_en AS "occurredAt" FROM emergencias.auditoria
      WHERE id > ${cursor ?? '0'}::bigint ORDER BY id LIMIT ${limit}`.execute(asKysely(tx))
    ).rows;
  }
}
