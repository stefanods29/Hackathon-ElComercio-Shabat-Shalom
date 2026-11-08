import type { Role } from '../../../shared/auth/actor.js';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';

export interface OperationalAccount {
  readonly id: string;
  readonly zoneId: string | null;
  readonly displayName: string;
  readonly trustLevel: number;
  readonly roles: readonly Role[];
}
/** Identity is the only module that reads accounts or certifies their trust and roles. */
export interface OperationalIdentity {
  find(tx: TransactionContext, userId: string): Promise<OperationalAccount | null>;
  certify(tx: TransactionContext, userId: string, role: Role, now: Date): Promise<void>;
  removeRole(tx: TransactionContext, userId: string, role: Role, now: Date): Promise<void>;
  zoneExists(tx: TransactionContext, zoneId: string): Promise<boolean>;
  contains(tx: TransactionContext, zoneId: string, lat: number, lng: number): Promise<boolean>;
}
export const OPERATIONAL_IDENTITY = Symbol('OPERATIONAL_IDENTITY');
