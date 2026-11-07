/**
 * Job queue port (section 4.3). At first the adapter runs on PostgreSQL (pg-boss, Lot B); when
 * volume demands it, it switches to BullMQ + Valkey without touching who enqueues or processes.
 */
export type JobPriority = 'critical' | 'normal' | 'low';

export interface JobOptions {
  readonly priority?: JobPriority;
  /** Retries with exponential backoff before the job goes to the dead-letter queue. */
  readonly retries?: number;
  /** Avoids duplicate jobs with the same key while one is pending. */
  readonly singletonKey?: string;
  readonly delaySeconds?: number;
}

export type JobHandler<T> = (data: T) => Promise<void>;

export interface JobQueue {
  enqueue<T>(name: string, data: T, options?: JobOptions): Promise<void>;
  process<T>(name: string, handler: JobHandler<T>): Promise<void>;
}

export const JOB_QUEUE = Symbol('JOB_QUEUE');
import type { TransactionContext } from '../db/unit-of-work.js';

/** Durable adapters can atomically publish alongside the outbox update. */
export interface TransactionalJobQueue extends JobQueue {
  enqueueInTransaction<T>(
    transaction: TransactionContext,
    name: string,
    data: T,
    options?: JobOptions,
  ): Promise<void>;
}

export function isTransactionalJobQueue(queue: JobQueue): queue is TransactionalJobQueue {
  return 'enqueueInTransaction' in queue && typeof queue.enqueueInTransaction === 'function';
}
