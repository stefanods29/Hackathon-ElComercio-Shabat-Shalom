import type { Actor } from '../../../shared/auth/actor.js';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';

export const ACCOUNT_PRIVACY_STORE = Symbol('ACCOUNT_PRIVACY_STORE');

export interface AccountPrivacyStore {
  resolveAccess(actor: Actor): Promise<Actor | null>;
  markDeleted(tx: TransactionContext, userId: string, now: Date): Promise<boolean>;
  findPendingPhone(tx: TransactionContext, userId: string, lock?: boolean): Promise<string | null>;
  rectify(tx: TransactionContext, userId: string, name: string, now: Date): Promise<boolean>;
}
