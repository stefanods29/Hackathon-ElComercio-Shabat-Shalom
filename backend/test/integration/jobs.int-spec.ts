import { Test } from '@nestjs/testing';
import { type Kysely, sql } from 'kysely';
import { inject } from 'vitest';
import { APP_CONFIG } from '../../src/shared/config/app-config.js';
import { createKysely } from '../../src/shared/db/connection.js';
import type { SharedTables } from '../../src/shared/db/shared-tables.js';
import { asJsonb, asKysely } from '../../src/shared/db/unit-of-work.kysely.js';
import type { TransactionContext } from '../../src/shared/db/unit-of-work.js';
import { newId } from '../../src/shared/domain/ids.js';
import { PostgresIdempotencyStore } from '../../src/shared/idempotency/idempotency-store.postgres.js';
import { OutboxRelay, type OutboxJob } from '../../src/shared/outbox/outbox-relay.js';
import { DAILY_CLEANUP_JOB, DailyCleanup } from '../../src/shared/queues/daily-cleanup.js';
import { JOB_QUEUE, type TransactionalJobQueue } from '../../src/shared/queues/job-queue.js';
import { PgBossJobQueue } from '../../src/shared/queues/job-queue.pgboss.js';
import { WorkersModule } from '../../src/workers/workers.module.js';
import { testConfig } from '../support/config.js';

const now = new Date('2026-11-07T13:00:00Z');
const clock = { now: () => now };
const schema = 'colas_pruebas';

describe('Trabajos durables y outbox (PostgreSQL real)', () => {
  let db: Kysely<SharedTables>;
  let queue: PgBossJobQueue;
  const extraQueues: PgBossJobQueue[] = [];

  async function startQueue(worker = false): Promise<PgBossJobQueue> {
    const adapter = new PgBossJobQueue(
      { DATABASE_URL: inject('databaseUrl') },
      { schema, worker, pollingIntervalSeconds: 0.5 },
    );
    await adapter.onModuleInit();
    extraQueues.push(adapter);
    return adapter;
  }

  async function addEvents(count: number, type = 'pruebas.relay'): Promise<string[]> {
    const ids = Array.from({ length: count }, () => newId());
    await db
      .insertInto('compartido.outbox')
      .values(
        ids.map((id) => ({
          id,
          modulo: 'solidaridad',
          tipo: type,
          agregado_id: newId(),
          carga: asJsonb({ publicacionId: newId() }),
          ocurrido_en: now,
          publicado_en: null,
        })),
      )
      .execute();
    return ids;
  }

  beforeAll(async () => {
    db = createKysely(inject('databaseUrl')) as Kysely<SharedTables>;
    queue = new PgBossJobQueue({ DATABASE_URL: inject('databaseUrl') }, { schema });
    await queue.onModuleInit();
    // Flush older fixtures so concurrent batches below contain exactly our 200 events.
    await new OutboxRelay(db, queue, clock).runOnce(10_000);
  });

  afterEach(async () => {
    for (const adapter of extraQueues.splice(0)) await adapter.beforeApplicationShutdown();
    await db.deleteFrom('compartido.outbox').where('tipo', 'like', 'pruebas.%').execute();
  });

  afterAll(async () => {
    await queue.beforeApplicationShutdown();
    await sql.raw('DROP SCHEMA IF EXISTS colas_pruebas CASCADE').execute(db);
    await db.destroy();
  });

  it('la API solo produce: no ejecuta manejadores ni programación', async () => {
    expect(queue.boss.isMaintaining()).toBe(false);
    expect(queue.boss.isTimekeeping()).toBe(false);
    await expect(queue.process('pruebas.prohibido', async () => {})).rejects.toThrow(/workers/);
  });

  it('procesa el crítico antes que 1.000 normales pendientes', async () => {
    const name = 'pruebas.prioridad';
    await Promise.all(
      Array.from({ length: 1000 }, (_, n) => queue.enqueue(name, { id: n, critical: false })),
    );
    await queue.enqueue(name, { id: 1000, critical: true }, { priority: 'critical' });
    const worker = await startQueue(true);
    const received: { critical: boolean }[] = [];
    await worker.process<{ critical: boolean }>(name, async (data) => {
      received.push(data);
    });
    await vi.waitFor(() => expect(received.length).toBeGreaterThan(0), { timeout: 10_000 });
    expect(received[0]?.critical).toBe(true);
  });

  it('deduplica claves concurrentes y conserva la demora y los reintentos', async () => {
    const name = 'pruebas.deduplicacion';
    await Promise.all(
      Array.from({ length: 10 }, () =>
        queue.enqueue(
          name,
          { id: 'mismo' },
          {
            singletonKey: 'mismo',
            delaySeconds: 60,
            retries: 2,
            priority: 'low',
          },
        ),
      ),
    );
    const jobs = await queue.boss.findJobs(name);
    expect(jobs).toHaveLength(1);
    expect(jobs[0]).toMatchObject({ priority: 0, retryLimit: 2, retryBackoff: true });
    expect(jobs[0]!.startAfter.getTime() - jobs[0]!.createdOn.getTime()).toBeGreaterThan(55_000);
  });

  it('agota los cinco reintentos y conserva el error en la cola de fallidos', async () => {
    const name = 'pruebas.fallo';
    await queue.enqueue(name, { avisoId: newId() });
    const worker = await startQueue(true);
    let attempts = 0;
    await worker.process(name, async () => {
      attempts++;
      throw new Error('Proveedor no disponible');
    });
    await vi.waitFor(
      async () => {
        // Accelerate only the test fixture, preserving pg-boss's real retry/failure transitions.
        await sql
          .raw(
            "UPDATE colas_pruebas.job SET start_after = now() WHERE name = 'pruebas.fallo' AND state = 'retry'",
          )
          .execute(db);
        const dead = await queue.boss.findJobs(name + '.fallidos');
        expect(dead).toHaveLength(1);
        expect(JSON.stringify(dead[0])).toContain('Proveedor no disponible');
      },
      { timeout: 20_000, interval: 50 },
    );
    expect(attempts).toBe(6); // Initial attempt plus retryLimit=5, as pg-boss defines it.
    const [original] = await queue.boss.findJobs(name);
    expect(original).toMatchObject({ state: 'failed', retryCount: 5, retryBackoff: true });
  });

  it('dos relays publican 200 eventos una sola vez con SKIP LOCKED', async () => {
    const ids = await addEvents(200);
    const otherQueue = await startQueue();
    const results = await Promise.all([
      new OutboxRelay(db, queue, clock).runOnce(100),
      new OutboxRelay(db, otherQueue, clock).runOnce(100),
    ]);
    expect(results.map((result) => result.published).sort((a, b) => a - b)).toEqual([100, 100]);
    const jobs = await queue.boss.findJobs<OutboxJob>('pruebas.relay');
    expect(jobs).toHaveLength(200);
    expect(new Set(jobs.map((job) => job.data.eventoId))).toEqual(new Set(ids));
    const rows = await db
      .selectFrom('compartido.outbox')
      .selectAll()
      .where('id', 'in', ids)
      .execute();
    expect(rows.every((row) => row.publicado_en !== null && row.intentos === 1)).toBe(true);
  });

  it('un fallo SQL revierte solo ese envío, persiste el intento y no bloquea el lote', async () => {
    const [failedId, goodId] = await addEvents(2, 'pruebas.recuperacion');
    const faultyQueue: TransactionalJobQueue = {
      enqueue: queue.enqueue.bind(queue),
      process: queue.process.bind(queue),
      enqueueInTransaction: async (tx, name, data, options) => {
        await queue.enqueueInTransaction(tx, name, data, options);
        if ((data as OutboxJob).eventoId === failedId) {
          await sql.raw('SELECT 1 / 0').execute(asKysely(tx));
        }
      },
    };
    const result = await new OutboxRelay(db, faultyQueue, clock).runOnce();
    expect(result).toEqual({ published: 1, failed: 1 });
    expect(
      (await queue.boss.findJobs<OutboxJob>('pruebas.recuperacion')).map(
        (job) => job.data.eventoId,
      ),
    ).toEqual([goodId]);
    const failed = await db
      .selectFrom('compartido.outbox')
      .selectAll()
      .where('id', '=', failedId!)
      .executeTakeFirstOrThrow();
    expect(failed).toMatchObject({ publicado_en: null, intentos: 1 });
    expect(await new OutboxRelay(db, queue, clock).runOnce()).toEqual({ published: 1, failed: 0 });
    expect(await queue.boss.findJobs('pruebas.recuperacion')).toHaveLength(2);
  });

  it('una caída antes del commit no deja un trabajo huérfano y el reinicio lo recupera', async () => {
    const [id] = await addEvents(1, 'pruebas.reinicio');
    await expect(
      db.transaction().execute(async (tx) => {
        await queue.enqueueInTransaction(
          tx as unknown as TransactionContext,
          'pruebas.reinicio',
          { eventoId: id },
          { singletonKey: id },
        );
        throw new Error('caída antes del commit');
      }),
    ).rejects.toThrow(/caída/);
    expect(await queue.boss.findJobs('pruebas.reinicio')).toHaveLength(0);
    const restarted = await startQueue();
    expect(await new OutboxRelay(db, restarted, clock).runOnce()).toEqual({
      published: 1,
      failed: 0,
    });
    expect(await restarted.boss.findJobs('pruebas.reinicio')).toHaveLength(1);
    expect(await new OutboxRelay(db, restarted, clock).runOnce()).toEqual({
      published: 0,
      failed: 0,
    });
  });

  it('limpia solo claves vencidas y outbox publicado con más de 30 días', async () => {
    const store = new PostgresIdempotencyStore(db, 24);
    const old = new Date(now.getTime() - 40 * 86_400_000);
    const recent = new Date(now.getTime() - 86_400_000);
    const request = {
      scope: 'pruebas.limpieza',
      method: 'POST',
      path: '/v1/prueba',
      fingerprint: 'x',
    };
    await store.reserve({ ...request, key: 'clave-vencida' }, old);
    await store.reserve({ ...request, key: 'clave-vigente' }, now);
    const [oldId, recentId, pendingId] = await addEvents(3, 'pruebas.limpieza');
    await db
      .updateTable('compartido.outbox')
      .set({ publicado_en: old })
      .where('id', '=', oldId!)
      .execute();
    await db
      .updateTable('compartido.outbox')
      .set({ publicado_en: recent })
      .where('id', '=', recentId!)
      .execute();
    const cleanup = new DailyCleanup(db, store, clock);
    const result = await cleanup.run();
    expect(result.idempotencyKeys).toBeGreaterThanOrEqual(1);
    expect(result.outboxEvents).toBeGreaterThanOrEqual(1);
    const keys = await db
      .selectFrom('compartido.idempotencia')
      .select('clave')
      .where('alcance', '=', request.scope)
      .execute();
    expect(keys.map((row) => row.clave)).toEqual(['clave-vigente']);
    const remaining = await db
      .selectFrom('compartido.outbox')
      .select('id')
      .where('id', 'in', [oldId!, recentId!, pendingId!])
      .execute();
    expect(new Set(remaining.map((row) => row.id))).toEqual(new Set([recentId, pendingId]));
    expect(await cleanup.run()).toEqual({ idempotencyKeys: 0, outboxEvents: 0 });
  });

  it('arranca el proceso Nest de workers, programa la limpieza en Lima y cierra sus recursos', async () => {
    const [id] = await addEvents(1, 'pruebas.worker');
    const config = testConfig({ DATABASE_URL: inject('databaseUrl'), JOB_QUEUE_DRIVER: 'pgboss' });
    const context = await Test.createTestingModule({ imports: [WorkersModule] })
      .overrideProvider(APP_CONFIG)
      .useValue(config)
      .compile();
    try {
      await context.init();
      const workerQueue = context.get<PgBossJobQueue>(JOB_QUEUE);
      expect(workerQueue).toBeInstanceOf(PgBossJobQueue);
      const schedule = await workerQueue.boss.getSchedule(DAILY_CLEANUP_JOB);
      expect(schedule).toMatchObject({ cron: '0 4 * * *', timezone: 'America/Lima' });
      await vi.waitFor(async () => {
        const row = await db
          .selectFrom('compartido.outbox')
          .select('publicado_en')
          .where('id', '=', id!)
          .executeTakeFirstOrThrow();
        expect(row.publicado_en).not.toBeNull();
      });
    } finally {
      await context.close();
    }
  });
});
