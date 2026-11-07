export interface QueueDepth {
  readonly name: string;
  readonly pending: number;
  readonly active: number;
  readonly failed: number;
  readonly criticalPending: number;
  readonly oldestCriticalAgeSeconds: number | null;
}

export interface QueueMetricsReader {
  readonly driver: 'pgboss' | 'memory';
  depths(now: Date): Promise<QueueDepth[]>;
}

export const QUEUE_METRICS_READER = Symbol('QUEUE_METRICS_READER');
