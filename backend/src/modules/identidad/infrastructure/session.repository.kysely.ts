import { Injectable } from '@nestjs/common';
import { type Selectable, sql } from 'kysely';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import { asKysely } from '../../../shared/db/unit-of-work.kysely.js';
import type {
  SessionRecord,
  SessionRepository,
  SessionRevocationReason,
} from '../application/session-ports.js';
import type { IdentityTables, SessionsTable } from './tables.js';

function toSession(row: Selectable<SessionsTable>): SessionRecord {
  return {
    id: row.id,
    userId: row.usuario_id,
    familyId: row.familia_id,
    refreshHash: row.refresh_hash,
    device: row.dispositivo,
    createdAt: row.creada_en,
    expiresAt: row.expira_en,
    rotatedAt: row.rotada_en,
    revokedAt: row.revocada_en,
    reason: row.motivo,
  };
}

@Injectable()
export class KyselySessionRepository implements SessionRepository {
  async lockUser(transaction: TransactionContext, userId: string): Promise<void> {
    // Serializes rotation, creation and revocation, including inserts in other families.
    await sql`SELECT pg_advisory_xact_lock(hashtextextended(${`identidad:sesiones:usuario:${userId}`}, 0))`.execute(
      asKysely(transaction),
    );
  }

  async create(transaction: TransactionContext, record: SessionRecord): Promise<void> {
    await asKysely<IdentityTables>(transaction)
      .insertInto('identidad.sesiones')
      .values({
        id: record.id,
        usuario_id: record.userId,
        familia_id: record.familyId,
        refresh_hash: record.refreshHash,
        dispositivo: record.device,
        creada_en: record.createdAt,
        expira_en: record.expiresAt,
        rotada_en: record.rotatedAt,
        revocada_en: record.revokedAt,
        motivo: record.reason,
      })
      .execute();
  }

  async findByHash(transaction: TransactionContext, hash: string): Promise<SessionRecord | null> {
    const row = await asKysely<IdentityTables>(transaction)
      .selectFrom('identidad.sesiones')
      .selectAll()
      .where('refresh_hash', '=', hash)
      .executeTakeFirst();
    return row ? toSession(row) : null;
  }

  async findByHashForUpdate(
    transaction: TransactionContext,
    hash: string,
  ): Promise<SessionRecord | null> {
    const row = await asKysely<IdentityTables>(transaction)
      .selectFrom('identidad.sesiones')
      .selectAll()
      .where('refresh_hash', '=', hash)
      .forUpdate()
      .executeTakeFirst();
    return row ? toSession(row) : null;
  }

  async markRotated(transaction: TransactionContext, id: string, now: Date): Promise<void> {
    await asKysely<IdentityTables>(transaction)
      .updateTable('identidad.sesiones')
      .set({ rotada_en: now })
      .where('id', '=', id)
      .execute();
  }

  async revokeFamily(
    transaction: TransactionContext,
    userId: string,
    familyId: string,
    now: Date,
    reason: SessionRevocationReason,
  ): Promise<void> {
    await asKysely<IdentityTables>(transaction)
      .updateTable('identidad.sesiones')
      .set({ revocada_en: now, motivo: reason })
      .where('usuario_id', '=', userId)
      .where('familia_id', '=', familyId)
      .where('revocada_en', 'is', null)
      .execute();
  }

  async revokeAll(transaction: TransactionContext, userId: string, now: Date): Promise<void> {
    await asKysely<IdentityTables>(transaction)
      .updateTable('identidad.sesiones')
      .set({ revocada_en: now, motivo: 'revocacion_total' })
      .where('usuario_id', '=', userId)
      .where('revocada_en', 'is', null)
      .execute();
  }

  async hasActiveFamily(
    transaction: TransactionContext,
    userId: string,
    familyId: string,
    now: Date,
  ): Promise<boolean> {
    const row = await asKysely<IdentityTables>(transaction)
      .selectFrom('identidad.sesiones')
      .select('id')
      .where('usuario_id', '=', userId)
      .where('familia_id', '=', familyId)
      .where('revocada_en', 'is', null)
      .where('rotada_en', 'is', null)
      .where('expira_en', '>', now)
      .executeTakeFirst();
    return row !== undefined;
  }
}
