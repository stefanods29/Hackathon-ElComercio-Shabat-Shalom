import { Inject, Injectable, Logger } from '@nestjs/common';
import { type Kysely, sql } from 'kysely';
import { KYSELY } from '../db/connection.js';
import type { SharedTables } from '../db/shared-tables.js';
import type { TransactionContext } from '../db/unit-of-work.js';
import { CLOCK, type Clock } from '../domain/clock.js';
import { JOB_QUEUE, type JobQueue, isTransactionalJobQueue } from '../queues/job-queue.js';

export interface OutboxJob {
  readonly eventoId: string;
  readonly modulo: string;
  readonly agregadoId: string;
  readonly carga: unknown;
  readonly ocurridoEn: string;
}

@Injectable()
export class OutboxRelay {
  private readonly logger = new Logger(OutboxRelay.name);

  constructor(
    @Inject(KYSELY) private readonly db: Kysely<SharedTables>,
    @Inject(JOB_QUEUE) private readonly queue: JobQueue,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  async runOnce(batchSize = 100): Promise<{ published: number; failed: number }> {
    if (!Number.isInteger(batchSize) || batchSize < 1) throw new Error('Lote inválido del relay.');
    return this.db.transaction().execute(async (tx) => {
      const rows = await tx
        .selectFrom('compartido.outbox')
        .selectAll()
        .where('publicado_en', 'is', null)
        .orderBy('ocurrido_en')
        .orderBy('id')
        .limit(batchSize)
        .forUpdate()
        .skipLocked()
        .execute();
      let published = 0;
      let failed = 0;
      for (const row of rows) {
        await sql.raw('SAVEPOINT outbox_item').execute(tx);
        try {
          const data: OutboxJob = {
            eventoId: row.id,
            modulo: row.modulo,
            agregadoId: row.agregado_id,
            carga: row.carga,
            ocurridoEn: row.ocurrido_en.toISOString(),
          };
          const options = {
            singletonKey: row.id,
            priority: row.modulo === 'emergencias' ? ('critical' as const) : ('normal' as const),
          };
          if (isTransactionalJobQueue(this.queue)) {
            await this.queue.enqueueInTransaction(
              tx as unknown as TransactionContext,
              row.tipo,
              data,
              options,
            );
          } else {
            // Only the test double is nontransactional. Workers require the durable adapter.
            await this.queue.enqueue(row.tipo, data, options);
          }
          await tx
            .updateTable('compartido.outbox')
            .set((eb) => ({ publicado_en: this.clock.now(), intentos: eb('intentos', '+', 1) }))
            .where('id', '=', row.id)
            .execute();
          published++;
        } catch {
          // Recover a failed SQL statement too, without aborting the remainder of the batch.
          await sql.raw('ROLLBACK TO SAVEPOINT outbox_item').execute(tx);
          await tx
            .updateTable('compartido.outbox')
            .set((eb) => ({ intentos: eb('intentos', '+', 1) }))
            .where('id', '=', row.id)
            .execute();
          failed++;
          this.logger.warn('Evento pendiente tras un fallo de publicación: ' + row.id);
        }
        await sql.raw('RELEASE SAVEPOINT outbox_item').execute(tx);
      }
      return { published, failed };
    });
  }
}
