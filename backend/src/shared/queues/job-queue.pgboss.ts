import { type BeforeApplicationShutdown, Logger, type OnModuleInit } from '@nestjs/common';
import { PgBoss, fromKysely, type SendOptions } from 'pg-boss';
import type { AppConfig } from '../config/app-config.js';
import { asKysely } from '../db/unit-of-work.kysely.js';
import type { TransactionContext } from '../db/unit-of-work.js';
import { newId } from '../domain/ids.js';
import type { JobHandler, JobOptions, TransactionalJobQueue } from './job-queue.js';

const PRIORITIES = { critical: 20, normal: 10, low: 0 } as const;

export interface PgBossRuntimeOptions {
  readonly worker?: boolean;
  readonly schema?: string;
  readonly pollingIntervalSeconds?: number;
}

/** The API only produces jobs; only the worker process runs supervision and schedules. */
export class PgBossJobQueue
  implements TransactionalJobQueue, OnModuleInit, BeforeApplicationShutdown
{
  readonly boss: PgBoss;
  private readonly logger = new Logger(PgBossJobQueue.name);
  private readonly queues = new Map<string, Promise<void>>();
  private started = false;

  constructor(
    config: Pick<AppConfig, 'DATABASE_URL'>,
    private readonly options: PgBossRuntimeOptions = {},
  ) {
    this.boss = new PgBoss({
      connectionString: config.DATABASE_URL,
      schema: options.schema ?? 'colas',
      supervise: options.worker ?? false,
      schedule: options.worker ?? false,
    });
    this.boss.on('error', (error) => this.logger.error(error.message));
  }

  async onModuleInit(): Promise<void> {
    await this.boss.start();
    this.started = true;
  }

  async beforeApplicationShutdown(): Promise<void> {
    if (!this.started) return;
    await this.boss.stop({ graceful: true, timeout: 30_000 });
    this.started = false;
  }

  async ensureQueue(name: string): Promise<void> {
    let pending = this.queues.get(name);
    if (!pending) {
      pending = (async () => {
        await this.boss.createQueue(name + '.fallidos');
        await this.boss.createQueue(name, {
          policy: 'exclusive',
          retryLimit: 5,
          retryDelay: 1,
          retryBackoff: true,
          deadLetter: name + '.fallidos',
        });
      })();
      this.queues.set(name, pending);
    }
    try {
      await pending;
    } catch (error) {
      if (this.queues.get(name) === pending) this.queues.delete(name);
      throw error;
    }
  }

  async enqueue<T>(name: string, data: T, options: JobOptions = {}): Promise<void> {
    await this.ensureQueue(name);
    await this.boss.send(name, data as object, this.sendOptions(options));
  }

  async enqueueInTransaction<T>(
    transaction: TransactionContext,
    name: string,
    data: T,
    options: JobOptions = {},
  ): Promise<void> {
    await this.ensureQueue(name);
    await this.boss.send(name, data as object, {
      ...this.sendOptions(options),
      db: fromKysely(asKysely(transaction)),
    });
  }

  async process<T>(name: string, handler: JobHandler<T>): Promise<void> {
    this.requireWorker();
    await this.ensureQueue(name);
    await this.boss.work<T>(
      name,
      {
        batchSize: 1,
        localConcurrency: 1,
        priority: true,
        pollingIntervalSeconds: this.options.pollingIntervalSeconds ?? 1,
      },
      async (jobs) => {
        for (const job of jobs) await handler(job.data);
      },
    );
  }

  async schedule(name: string, cron: string, timezone: string): Promise<void> {
    this.requireWorker();
    await this.ensureQueue(name);
    await this.boss.schedule(
      name,
      cron,
      {},
      {
        tz: timezone,
        ...this.sendOptions({ priority: 'low', singletonKey: name }),
      },
    );
  }

  private sendOptions(options: JobOptions): SendOptions {
    return {
      priority: PRIORITIES[options.priority ?? 'normal'],
      retryLimit: options.retries ?? 5,
      retryDelay: 1,
      retryBackoff: true,
      singletonKey: options.singletonKey ?? newId(),
      startAfter: options.delaySeconds ?? 0,
    };
  }

  private requireWorker(): void {
    if (!this.options.worker) {
      throw new Error('La API solo encola trabajos; usa el proceso de workers para ejecutarlos.');
    }
  }
}
