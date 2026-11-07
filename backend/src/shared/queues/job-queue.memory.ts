import type { JobHandler, JobOptions, JobQueue } from './job-queue.js';

interface PendingJob {
  readonly name: string;
  readonly data: unknown;
  readonly options: JobOptions;
}

const PRIORITY_ORDER = { critical: 0, normal: 1, low: 2 } as const;

/**
 * In-memory queue for development and tests. It does not process on its own: `drain()` runs
 * the pending jobs by priority, so tests stay deterministic.
 */
export class InMemoryJobQueue implements JobQueue {
  private readonly pending: PendingJob[] = [];
  private readonly handlers = new Map<string, JobHandler<unknown>>();

  async enqueue<T>(name: string, data: T, options: JobOptions = {}): Promise<void> {
    const duplicate =
      options.singletonKey !== undefined &&
      this.pending.some(
        (job) => job.name === name && job.options.singletonKey === options.singletonKey,
      );
    if (!duplicate) {
      this.pending.push({ name, data, options });
    }
  }

  async process<T>(name: string, handler: JobHandler<T>): Promise<void> {
    this.handlers.set(name, handler as JobHandler<unknown>);
  }

  get pendingCount(): number {
    return this.pending.length;
  }

  async drain(): Promise<void> {
    this.pending.sort(
      (a, b) =>
        PRIORITY_ORDER[a.options.priority ?? 'normal'] -
        PRIORITY_ORDER[b.options.priority ?? 'normal'],
    );
    while (this.pending.length > 0) {
      const job = this.pending.shift();
      if (!job) break;
      const handler = this.handlers.get(job.name);
      if (!handler) {
        throw new Error(`No hay manejador registrado para el trabajo "${job.name}"`);
      }
      await handler(job.data);
    }
  }
}
