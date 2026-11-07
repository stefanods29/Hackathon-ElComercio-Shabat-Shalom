import type { TransactionContext } from '../db/unit-of-work.js';
import type { DomainEvent } from '../domain/domain-event.js';
import type { OutboxWriter } from './outbox.js';

/** Test double: keeps the events in memory so they can be asserted. */
export class InMemoryOutboxWriter implements OutboxWriter {
  readonly recorded: Array<DomainEvent & { module: string }> = [];

  async record(
    _transaction: TransactionContext,
    module: string,
    events: readonly DomainEvent[],
  ): Promise<void> {
    this.recorded.push(...events.map((event) => ({ ...event, module })));
  }
}
