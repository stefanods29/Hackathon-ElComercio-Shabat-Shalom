import { Inject, Injectable } from '@nestjs/common';
import type { Kysely } from 'kysely';
import { KYSELY } from '../db/connection.js';
import type { SharedTables } from '../db/shared-tables.js';
import { CLOCK, type Clock } from '../domain/clock.js';
import { IDEMPOTENCY_STORE } from '../idempotency/idempotency-store.js';
import type { PostgresIdempotencyStore } from '../idempotency/idempotency-store.postgres.js';

export const DAILY_CLEANUP_JOB = 'plataforma.limpieza_diaria';

@Injectable()
export class DailyCleanup {
  constructor(
    @Inject(KYSELY) private readonly db: Kysely<SharedTables>,
    @Inject(IDEMPOTENCY_STORE) private readonly idempotency: PostgresIdempotencyStore,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  async run(): Promise<{ idempotencyKeys: number; outboxEvents: number }> {
    const now = this.clock.now();
    const idempotencyKeys = await this.idempotency.deleteExpired(now);
    const cutoff = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    const result = await this.db
      .deleteFrom('compartido.outbox')
      .where('publicado_en', '<', cutoff)
      .executeTakeFirst();
    return { idempotencyKeys, outboxEvents: Number(result.numDeletedRows) };
  }
}
