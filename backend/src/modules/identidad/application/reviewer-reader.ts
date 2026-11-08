import type { TransactionContext } from '../../../shared/db/unit-of-work.js';

export interface ReviewerContext {
  readonly createdAt: Date;
  readonly deviceHash: string | null;
}

/** Exposes account age and a pseudonymous signal, never phone or device text. */
export interface ReviewerReader {
  findReviewer(
    transaction: TransactionContext,
    userId: string,
    sessionId?: string,
  ): Promise<ReviewerContext | null>;
}

export const REVIEWER_READER = Symbol('REVIEWER_READER');
