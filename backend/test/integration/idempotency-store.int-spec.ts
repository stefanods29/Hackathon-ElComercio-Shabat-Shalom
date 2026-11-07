import { type Kysely, sql } from 'kysely';
import { inject } from 'vitest';
import { createKysely } from '../../src/shared/db/connection.js';
import type { SharedTables } from '../../src/shared/db/shared-tables.js';
import type { IdempotentRequest } from '../../src/shared/idempotency/idempotency-store.js';
import { PostgresIdempotencyStore } from '../../src/shared/idempotency/idempotency-store.postgres.js';

describe('PostgresIdempotencyStore', () => {
  let db: Kysely<SharedTables>;
  let store: PostgresIdempotencyStore;
  const now = new Date('2026-11-06T15:00:00Z');
  let counter = 0;

  const idempotentRequest = (changes: Partial<IdempotentRequest> = {}): IdempotentRequest => ({
    scope: 'vecina-ana',
    key: `clave-de-prueba-${++counter}`,
    method: 'POST',
    path: '/v1/publicaciones',
    fingerprint: 'h1',
    ...changes,
  });

  beforeAll(() => {
    db = createKysely(inject('databaseUrl'), 12) as unknown as Kysely<SharedTables>;
    store = new PostgresIdempotencyStore(db, 168);
  });

  afterAll(async () => {
    await db.destroy();
  });

  it('si llegan 10 reintentos a la vez, solo uno ejecuta la acción', async () => {
    const same = idempotentRequest();
    const results = await Promise.all(Array.from({ length: 10 }, () => store.reserve(same, now)));
    expect(results.filter((result) => result.kind === 'new')).toHaveLength(1);
    expect(results.filter((result) => result.kind === 'in_progress')).toHaveLength(9);
  });

  it('guarda la respuesta (incluido un arreglo JSON) y la repite', async () => {
    const same = idempotentRequest();
    await store.reserve(same, now);
    await store.complete(same.scope, same.key, 201, [{ id: 'a' }, { id: 'b' }]);
    await expect(store.reserve(same, now)).resolves.toEqual({
      kind: 'replay',
      httpStatus: 201,
      body: [{ id: 'a' }, { id: 'b' }],
    });
  });

  it('detecta la misma clave con otro contenido y separa por usuario', async () => {
    const same = idempotentRequest();
    await store.reserve(same, now);
    await expect(store.reserve({ ...same, fingerprint: 'otra' }, now)).resolves.toEqual({
      kind: 'fingerprint_mismatch',
    });
    await expect(store.reserve({ ...same, scope: 'vecino-beto' }, now)).resolves.toEqual({
      kind: 'new',
    });
  });

  it('retoma una reserva abandonada (la API se reinició a mitad de camino)', async () => {
    const same = idempotentRequest();
    await store.reserve(same, now);
    const later = new Date(now.getTime() + 61_000);
    await expect(store.reserve(same, later)).resolves.toEqual({ kind: 'new' });
    await expect(store.reserve(same, later)).resolves.toEqual({ kind: 'in_progress' });
  });

  it('liberar permite reintentar y las claves vencidas se reutilizan', async () => {
    const same = idempotentRequest();
    await store.reserve(same, now);
    await store.release(same.scope, same.key);
    await expect(store.reserve(same, now)).resolves.toEqual({ kind: 'new' });

    const expired = idempotentRequest();
    await store.reserve(expired, now);
    await store.complete(expired.scope, expired.key, 201, { ok: true });
    const inEightDays = new Date(now.getTime() + 8 * 24 * 3_600_000);
    await expect(store.reserve({ ...expired, fingerprint: 'nueva' }, inEightDays)).resolves.toEqual(
      { kind: 'new' },
    );
    expect(
      await store.deleteExpired(new Date(now.getTime() + 30 * 24 * 3_600_000)),
    ).toBeGreaterThan(0);
  });

  it('la tabla existe en el esquema compartido', async () => {
    const { rows } = await sql<{ total: number }>`
      SELECT count(*)::int AS total FROM information_schema.tables
      WHERE table_schema = 'compartido' AND table_name = 'idempotencia'
    `.execute(db);
    expect(rows[0]?.total).toBe(1);
  });
});
