import type { TransactionContext } from '../db/unit-of-work.js';
import type { DomainEvent } from '../domain/domain-event.js';

/**
 * Transactional Outbox: events are stored in the SAME transaction as the change that produced
 * them. A worker (Lot B) reads them later and publishes them to the job queue.
 */
export interface OutboxWriter {
  record(
    transaction: TransactionContext,
    module: string,
    events: readonly DomainEvent[],
  ): Promise<void>;
}

export const OUTBOX_WRITER = Symbol('OUTBOX_WRITER');
