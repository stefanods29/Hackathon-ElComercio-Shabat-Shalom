declare const transactionBrand: unique symbol;

/**
 * Opaque transaction for the use cases: the application layer hands it to repositories and to
 * the outbox without knowing that Kysely is underneath. Only adapters unwrap it.
 */
export interface TransactionContext {
  readonly [transactionBrand]: true;
}

/** Unit of Work port: everything done inside `run` is committed or rolled back together. */
export interface UnitOfWork {
  run<T>(work: (transaction: TransactionContext) => Promise<T>): Promise<T>;
}

export const UNIT_OF_WORK = Symbol('UNIT_OF_WORK');
