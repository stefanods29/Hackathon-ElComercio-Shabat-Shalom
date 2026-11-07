import type { JobHandler, JobOptions, JobQueue } from './job-queue.js';
import { type Clock, systemClock } from '../domain/clock.js';
import type { QueueDepth, QueueMetricsReader } from './queue-metrics.js';

interface PendingJob {
  readonly name: string;
  readonly data: unknown;
  readonly options: JobOptions;
  readonly createdAt: Date;
}

const PRIORITY_ORDER = { critical: 0, normal: 1, low: 2 } as const;

/**
 * In-memory queue for development and tests. It does not process on its own: `drain()` runs
 * the pending jobs by priority, so tests stay deterministic.
 */
export class InMemoryJobQueue implements JobQueue, QueueMetricsReader {
  readonly driver = 'memory' as const;
  private readonly pending: PendingJob[] = [];
  private readonly handlers = new Map<string, JobHandler<unknown>>();
  private readonly active = new Map<string, number>();
  private readonly failed = new Map<string, number>();

  constructor(private readonly clock: Clock = systemClock) {}

  async enqueue<T>(name: string, data: T, options: JobOptions = {}): Promise<void> {
    const duplicate =
      options.singletonKey !== undefined &&
      this.pending.some(
        (job) => job.name === name && job.options.singletonKey === options.singletonKey,
      );
    if (!duplicate) {
      this.pending.push({ name, data, options, createdAt: this.clock.now() });
    }
  }

  async process<T>(name: string, handler: JobHandler<T>): Promise<void> {
    this.handlers.set(name, handler as JobHandler<unknown>);
  }

  get pendingCount(): number {
    return this.pending.length;
  }

  async depths(now: Date): Promise<QueueDepth[]> {
    const names = new Set([
      ...this.handlers.keys(),
      ...this.pending.map((job) => job.name),
      ...this.failed.keys(),
    ]);
    return [...names]
      .sort((left, right) => left.localeCompare(right))
      .map((name) => {
        const pending = this.pending.filter((job) => job.name === name);
        const critical = pending.filter((job) => job.options.priority === 'critical');
        const ready = critical.filter(
          (job) =>
            job.createdAt.getTime() + (job.options.delaySeconds ?? 0) * 1000 <= now.getTime(),
        );
        return {
          name,
          pending: pending.length,
          active: this.active.get(name) ?? 0,
          failed: this.failed.get(name) ?? 0,
          criticalPending: critical.length,
          oldestCriticalAgeSeconds: ready.length
            ? Math.max(
                0,
                (now.getTime() - Math.min(...ready.map((job) => job.createdAt.getTime()))) / 1000,
              )
            : null,
        };
      });
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
      this.active.set(job.name, (this.active.get(job.name) ?? 0) + 1);
      try {
        await handler(job.data);
      } catch (error) {
        this.failed.set(job.name, (this.failed.get(job.name) ?? 0) + 1);
        throw error;
      } finally {
        this.active.set(job.name, (this.active.get(job.name) ?? 0) - 1);
      }
    }
  }
}
