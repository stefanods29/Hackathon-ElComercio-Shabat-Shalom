import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import type {
  SessionRecord,
  SessionRepository,
  SessionRevocationReason,
} from '../application/session-ports.js';

/** Sequential unit-test double. PostgreSQL integration tests verify real locking. */
export class InMemorySessionRepository implements SessionRepository {
  readonly records = new Map<string, SessionRecord>();

  async lockUser(_transaction: TransactionContext, _userId: string): Promise<void> {}

  async create(_transaction: TransactionContext, record: SessionRecord): Promise<void> {
    this.records.set(record.id, structuredClone(record));
  }

  async findByHash(_transaction: TransactionContext, hash: string): Promise<SessionRecord | null> {
    return structuredClone(
      [...this.records.values()].find((record) => record.refreshHash === hash) ?? null,
    );
  }

  async findByHashForUpdate(
    transaction: TransactionContext,
    hash: string,
  ): Promise<SessionRecord | null> {
    return this.findByHash(transaction, hash);
  }

  async markRotated(_transaction: TransactionContext, id: string, now: Date): Promise<void> {
    const record = this.records.get(id);
    if (!record) throw new Error('Sesión inexistente');
    this.records.set(id, { ...record, rotatedAt: now });
  }

  async revokeFamily(
    _transaction: TransactionContext,
    userId: string,
    familyId: string,
    now: Date,
    reason: SessionRevocationReason,
  ): Promise<void> {
    for (const [id, record] of this.records) {
      if (record.userId === userId && record.familyId === familyId && !record.revokedAt) {
        this.records.set(id, { ...record, revokedAt: now, reason });
      }
    }
  }

  async revokeAll(_transaction: TransactionContext, userId: string, now: Date): Promise<void> {
    for (const [id, record] of this.records) {
      if (record.userId === userId && !record.revokedAt) {
        this.records.set(id, { ...record, revokedAt: now, reason: 'revocacion_total' });
      }
    }
  }

  async hasActiveFamily(
    _transaction: TransactionContext,
    userId: string,
    familyId: string,
    now: Date,
  ): Promise<boolean> {
    return [...this.records.values()].some(
      (record) =>
        record.userId === userId &&
        record.familyId === familyId &&
        !record.revokedAt &&
        !record.rotatedAt &&
        record.expiresAt.getTime() > now.getTime(),
    );
  }
}
