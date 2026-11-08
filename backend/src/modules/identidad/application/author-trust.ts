import type { TransactionContext } from '../../../shared/db/unit-of-work.js';

export const AUTHOR_TRUST = Symbol('AUTHOR_TRUST');
export interface AuthorTrust {
  trustLevel(tx: TransactionContext, userId: string): Promise<number | null>;
}
