import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import type { ConsentPurpose } from '../domain/consents.js';

export const RESIDENCE_STORE = Symbol('RESIDENCE_STORE');

export interface ResidenceAccount {
  readonly zoneId: string | null;
  readonly zoneChosenAt: Date | null;
  readonly level: number;
  readonly isModerator: boolean;
}

export interface ConsentDecision {
  readonly version: number;
  readonly accepted: boolean;
  readonly decidedAt: Date;
}

export interface ResidenceStore {
  findActive(tx: TransactionContext, userId: string): Promise<ResidenceAccount | null>;
  changeZone(tx: TransactionContext, userId: string, zoneId: string, now: Date): Promise<void>;
  updateLevel(tx: TransactionContext, userId: string, level: number, now: Date): Promise<void>;
  latestConsent(
    tx: TransactionContext,
    userId: string,
    purpose: ConsentPurpose,
  ): Promise<ConsentDecision | null>;
  recordConsent(
    tx: TransactionContext,
    userId: string,
    purpose: ConsentPurpose,
    decision: ConsentDecision,
  ): Promise<void>;
  recordPresence(
    tx: TransactionContext,
    userId: string,
    day: string,
    inside: boolean,
  ): Promise<void>;
  countPresenceDays(
    tx: TransactionContext,
    userId: string,
    since: string,
    until: string,
  ): Promise<number>;
  clearPresences(tx: TransactionContext, userId: string): Promise<void>;
  expirePresences(tx: TransactionContext, cutoff: string): Promise<void>;
  recordConfirmation(
    tx: TransactionContext,
    userId: string,
    zoneId: string,
    moderatorId: string,
    reason: string,
    level: 1 | 2,
    now: Date,
  ): Promise<void>;
  recordEndorsement(
    tx: TransactionContext,
    userId: string,
    zoneId: string,
    endorserId: string,
    now: Date,
  ): Promise<void>;
  countEndorsements(tx: TransactionContext, userId: string, zoneId: string): Promise<number>;
}
