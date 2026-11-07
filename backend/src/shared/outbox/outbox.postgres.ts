import type { SharedTables } from '../db/shared-tables.js';
import { asJsonb, asKysely } from '../db/unit-of-work.kysely.js';
import type { TransactionContext } from '../db/unit-of-work.js';
import type { DomainEvent } from '../domain/domain-event.js';
import { newId } from '../domain/ids.js';
import type { OutboxWriter } from './outbox.js';

export class PostgresOutboxWriter implements OutboxWriter {
  async record(
    transaction: TransactionContext,
    module: string,
    events: readonly DomainEvent[],
  ): Promise<void> {
    if (events.length === 0) return;
    await asKysely<SharedTables>(transaction)
      .insertInto('compartido.outbox')
      .values(
        events.map((event) => ({
          id: newId(),
          modulo: module,
          tipo: event.type,
          agregado_id: event.aggregateId,
          carga: asJsonb(event.payload),
          ocurrido_en: event.occurredAt,
        })),
      )
      .execute();
  }
}
