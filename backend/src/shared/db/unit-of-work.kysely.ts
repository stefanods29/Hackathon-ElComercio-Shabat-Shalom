import { type Kysely, type RawBuilder, type Transaction, sql } from 'kysely';
import type { TransactionContext, UnitOfWork } from './unit-of-work.js';

export class KyselyUnitOfWork implements UnitOfWork {
  constructor(private readonly db: Kysely<unknown>) {}

  run<T>(work: (transaction: TransactionContext) => Promise<T>): Promise<T> {
    return this.db.transaction().execute((trx) => work(trx as unknown as TransactionContext));
  }
}

/** Adapters only: recovers the Kysely transaction typed with the tables the module may see. */
export function asKysely<TTables>(transaction: TransactionContext): Transaction<TTables> {
  return transaction as unknown as Transaction<TTables>;
}

/** Writes a value as `jsonb` without `pg` turning arrays into Postgres arrays. */
export function asJsonb(value: unknown): RawBuilder<unknown> {
  return sql`cast(${JSON.stringify(value ?? null)} as jsonb)`;
}
