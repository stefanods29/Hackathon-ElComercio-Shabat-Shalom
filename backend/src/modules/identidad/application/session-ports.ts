import type { TransactionContext } from '../../../shared/db/unit-of-work.js';

export type SessionRevocationReason = 'cierre' | 'revocacion_total' | 'reutilizacion';

export interface SessionRecord {
  readonly id: string;
  readonly userId: string;
  readonly familyId: string;
  readonly refreshHash: string;
  readonly device: string | null;
  readonly createdAt: Date;
  readonly expiresAt: Date;
  readonly rotatedAt: Date | null;
  readonly revokedAt: Date | null;
  readonly reason: SessionRevocationReason | null;
}

export interface SessionRepository {
  /** All session mutations take this lock before any session row lock. */
  lockUser(transaction: TransactionContext, userId: string): Promise<void>;
  create(transaction: TransactionContext, record: SessionRecord): Promise<void>;
  findByHash(transaction: TransactionContext, hash: string): Promise<SessionRecord | null>;
  findByHashForUpdate(transaction: TransactionContext, hash: string): Promise<SessionRecord | null>;
  markRotated(transaction: TransactionContext, id: string, now: Date): Promise<void>;
  revokeFamily(
    transaction: TransactionContext,
    userId: string,
    familyId: string,
    now: Date,
    reason: SessionRevocationReason,
  ): Promise<void>;
  revokeAll(transaction: TransactionContext, userId: string, now: Date): Promise<void>;
  hasActiveFamily(
    transaction: TransactionContext,
    userId: string,
    familyId: string,
    now: Date,
  ): Promise<boolean>;
}

export const SESSION_REPOSITORY = Symbol('SESSION_REPOSITORY');
