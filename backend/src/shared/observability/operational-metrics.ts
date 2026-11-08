import { Inject, Injectable } from '@nestjs/common';
import { type Kysely, sql } from 'kysely';
import { KYSELY } from '../db/connection.js';
import { CLOCK, type Clock } from '../domain/clock.js';
import { QUEUE_METRICS_READER, type QueueMetricsReader } from '../queues/queue-metrics.js';
import { IdempotencyCounters } from './idempotency-counters.js';
import { SyncTelemetry } from './sync-telemetry.js';

@Injectable()
export class OperationalMetrics {
  constructor(
    @Inject(KYSELY) private readonly db: Kysely<unknown>,
    @Inject(QUEUE_METRICS_READER) private readonly queues: QueueMetricsReader,
    private readonly counters: IdempotencyCounters,
    @Inject(CLOCK) private readonly clock: Clock,
    private readonly telemetry: SyncTelemetry,
  ) {}

  async snapshot() {
    const now = this.clock.now();
    const [outbox, queues, sincronizacion] = await Promise.all([
      sql<{ pending: number; oldestAge: number | null }>`
        SELECT count(*)::int AS pending,
          CASE WHEN min(ocurrido_en) IS NULL THEN NULL ELSE
            greatest(0, extract(epoch FROM (${now}::timestamptz - min(ocurrido_en))))::double precision
          END AS "oldestAge" FROM compartido.outbox WHERE publicado_en IS NULL
      `.execute(this.db),
      this.queues.depths(now),
      this.telemetry.summary(),
    ]);
    return {
      instanciaId: this.counters.instanceId,
      desde: this.counters.startedAt.toISOString(),
      generadoEn: now.toISOString(),
      idempotencia: this.counters.snapshot(),
      outbox: {
        pendientes: outbox.rows[0]!.pending,
        edadMasAntiguoSegundos: outbox.rows[0]!.oldestAge,
      },
      colasMotor: this.queues.driver,
      colas: queues.map((queue) => ({
        nombre: queue.name,
        pendientes: queue.pending,
        activas: queue.active,
        fallidas: queue.failed,
        criticasPendientes: queue.criticalPending,
        edadCriticaMasAntiguaSegundos: queue.oldestCriticalAgeSeconds,
      })),
      sincronizacion,
    };
  }
}
