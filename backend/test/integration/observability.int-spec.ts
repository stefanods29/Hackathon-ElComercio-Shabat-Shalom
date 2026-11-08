import { Logger, type INestApplication } from '@nestjs/common';
import { type Kysely, sql } from 'kysely';
import request from 'supertest';
import { inject } from 'vitest';
import { NEIGHBORS, PILOT_ZONE } from '../../scripts/seed-data.js';
import { TokenService } from '../../src/shared/auth/token.service.js';
import { createKysely } from '../../src/shared/db/connection.js';
import { newId, isUuidV7 } from '../../src/shared/domain/ids.js';
import {
  IDEMPOTENCY_STORE,
  type IdempotencyStore,
} from '../../src/shared/idempotency/idempotency-store.js';
import { computeFingerprint } from '../../src/shared/idempotency/idempotency.interceptor.js';
import { HttpRequestLogger } from '../../src/shared/observability/request-id.middleware.js';
import { JOB_QUEUE } from '../../src/shared/queues/job-queue.js';
import { PgBossJobQueue } from '../../src/shared/queues/job-queue.pgboss.js';
import { OUTBOX_WRITER, type OutboxWriter } from '../../src/shared/outbox/outbox.js';
import { createTestApp } from '../support/app.js';

describe('Observabilidad por HTTP y PostgreSQL', () => {
  let app: INestApplication;
  let db: Kysely<unknown>;
  let admin: string;
  let neighbor: string;
  const server = () => app.getHttpServer();
  const metrics = () =>
    request(server()).get('/v1/operacion/metricas').auth(admin, { type: 'bearer' });
  const invalidBody = () => ({ id: newId(), tipo: 'presto', categoria: 'agua', titulo: 'xx' });

  beforeAll(async () => {
    ({ app } = await createTestApp(inject('databaseUrl'), { JOB_QUEUE_DRIVER: 'pgboss' }));
    await app.listen(0, '127.0.0.1');
    db = createKysely(inject('databaseUrl'), 2);
    // The guard keeps only the roles the account still has in the database (Phase 2, Lot B).
    await sql`UPDATE identidad.usuarios SET roles = array_append(roles, 'administrador')
      WHERE id = ${NEIGHBORS.carla.id} AND NOT ('administrador' = ANY(roles))`.execute(db);
    const tokens = app.get(TokenService);
    ({ token: admin } = await tokens.issueAccess({
      id: NEIGHBORS.carla.id,
      zoneId: PILOT_ZONE.id,
      trustLevel: 3,
      roles: ['administrador'],
    }));
    ({ token: neighbor } = await tokens.issueAccess({
      id: NEIGHBORS.ana.id,
      zoneId: PILOT_ZONE.id,
      trustLevel: 2,
      roles: [],
    }));
  });
  afterEach(() => vi.restoreAllMocks());
  afterAll(async () => {
    await app?.close();
    if (db) {
      await sql`UPDATE identidad.usuarios SET roles = array_remove(roles, 'administrador')
        WHERE id = ${NEIGHBORS.carla.id}`.execute(db);
    }
    await db?.destroy();
  });

  it('exige administrador y correlaciona también los rechazos del guard', async () => {
    const missing = await request(server()).get('/v1/operacion/metricas').expect(401);
    expect(missing.body.requestId).toBe(missing.headers['x-request-id']);
    expect(missing.body.instance).toContain(missing.body.requestId);
    const forbidden = await request(server())
      .get('/v1/operacion/metricas')
      .auth(neighbor, { type: 'bearer' })
      .expect(403);
    expect(forbidden.body.codigo).toBe('rol_requerido');
    expect((await metrics().expect(200)).body.colasMotor).toBe('pgboss');
  });

  it('propaga requestId y registra ruta/duración sin URL completa, credenciales ni cuerpos', async () => {
    const record = vi.spyOn(app.get(HttpRequestLogger), 'record');
    await request(server())
      .get('/v1/operacion/metricas?token=NO_REGISTRAR&lat=PRIVADO')
      .auth(admin, { type: 'bearer' })
      .set('x-request-id', 'traza-cliente-1')
      .expect('x-request-id', 'traza-cliente-1')
      .expect(200);
    expect(record).toHaveBeenCalledWith(
      expect.objectContaining({
        requestId: 'traza-cliente-1',
        ruta: '/v1/operacion/metricas',
        estado: 200,
        duracionMs: expect.any(Number),
      }),
    );
    expect(JSON.stringify(record.mock.calls)).not.toMatch(/NO_REGISTRAR|PRIVADO|Bearer/);
    const replaced = await metrics().set('x-request-id', 'cabecera con espacios').expect(200);
    expect(isUuidV7(replaced.headers['x-request-id']!)).toBe(true);
    const error = await request(server())
      .get('/ruta-inexistente?token=NO_REGISTRAR')
      .auth(admin, { type: 'bearer' })
      .expect(404);
    expect(error.body.instance).not.toContain('NO_REGISTRAR');
    expect(error.body.requestId).toBe(error.headers['x-request-id']);
  });

  it('un problema guardado mantiene el rechazo con nueva correlación, sin modificar el cache', async () => {
    const key = newId();
    const body = invalidBody();
    const send = (id: string) =>
      request(server())
        .post('/v1/publicaciones')
        .auth(neighbor, { type: 'bearer' })
        .set('Idempotency-Key', key)
        .set('x-request-id', id)
        .send(body);
    const first = await send('solicitud-primera').expect(400);
    const second = await send('solicitud-segunda').expect(400);
    expect(second.headers['idempotent-replayed']).toBe('true');
    expect(second.body).toMatchObject({
      codigo: first.body.codigo,
      errores: first.body.errores,
      requestId: 'solicitud-segunda',
      instance: '/v1/publicaciones#requestId=solicitud-segunda',
    });
    expect(first.body.requestId).toBe('solicitud-primera');
    const stored = await sql<{
      body: Record<string, unknown>;
    }>`SELECT cuerpo_respuesta AS body FROM compartido.idempotencia WHERE alcance = ${NEIGHBORS.ana.id} AND clave = ${key}`.execute(
      db,
    );
    expect(stored.rows[0]?.body).not.toHaveProperty('requestId');
  });

  it('cuenta nueva, repetida, en curso y huella distinta por instancia', async () => {
    const before = (await metrics().expect(200)).body;
    const key = newId();
    const body = invalidBody();
    const send = (data: object, sentKey = key) =>
      request(server())
        .post('/v1/publicaciones')
        .auth(neighbor, { type: 'bearer' })
        .set('Idempotency-Key', sentKey)
        .send(data);
    await send(body).expect(400);
    await send(body).expect(400);
    await send({ ...body, titulo: 'Prueba corregida' }).expect(422);
    const pendingKey = newId();
    await app.get<IdempotencyStore>(IDEMPOTENCY_STORE).reserve(
      {
        scope: NEIGHBORS.ana.id,
        key: pendingKey,
        method: 'POST',
        path: '/v1/publicaciones',
        fingerprint: computeFingerprint('POST', '/v1/publicaciones', body),
      },
      new Date(),
    );
    await send(body, pendingKey).expect(409);
    const after = (await metrics().expect(200)).body;
    expect(after.instanciaId).toBe(before.instanciaId);
    expect(after.idempotencia).toEqual({
      nueva: before.idempotencia.nueva + 1,
      repetida: before.idempotencia.repetida + 1,
      enCurso: before.idempotencia.enCurso + 1,
      huellaDistinta: before.idempotencia.huellaDistinta + 1,
    });
  });

  it('mide outbox pendiente y edad sin devolver cargas', async () => {
    const id = newId();
    const before = (await metrics().expect(200)).body.outbox.pendientes as number;
    await sql`INSERT INTO compartido.outbox (id, modulo, tipo, agregado_id, carga, ocurrido_en)
      VALUES (${id}, 'prueba', 'prueba.medicion', ${newId()}, '{"privado":"NO_REGISTRAR"}'::jsonb, now() - interval '2 minutes')`.execute(
      db,
    );
    const snapshot = (await metrics().expect(200)).body;
    expect(snapshot.outbox.pendientes).toBe(before + 1);
    expect(snapshot.outbox.edadMasAntiguoSegundos).toBeGreaterThanOrEqual(120);
    expect(JSON.stringify(snapshot)).not.toContain('NO_REGISTRAR');
    await sql`UPDATE compartido.outbox SET publicado_en = now() WHERE id = ${id}`.execute(db);
    expect((await metrics().expect(200)).body.outbox.pendientes).toBe(before);
  });

  it('consulta la cola real inmediatamente: pendientes, críticos, activos, fallidos y cola vacía', async () => {
    const queue = app.get<PgBossJobQueue>(JOB_QUEUE);
    const name = 'observabilidad.' + newId();
    await queue.enqueue(name, { privado: 'NO_REGISTRAR' }, { priority: 'critical', retries: 0 });
    await queue.enqueue(name, {}, { priority: 'critical' });
    await queue.enqueue(name, {}, { priority: 'normal', delaySeconds: 600 });
    await queue.enqueue(name, {}, { priority: 'critical', delaySeconds: 600 });
    const find = async () =>
      ((await metrics().expect(200)).body.colas as Array<Record<string, unknown>>).find(
        (item) => item.nombre === name,
      )!;
    expect(await find()).toMatchObject({
      pendientes: 4,
      activas: 0,
      fallidas: 0,
      criticasPendientes: 3,
      edadCriticaMasAntiguaSegundos: expect.any(Number),
    });
    const emptyName = 'observabilidad.vacia.' + newId();
    await queue.ensureQueue(emptyName);
    const empty = ((await metrics().expect(200)).body.colas as Array<Record<string, unknown>>).find(
      (item) => item.nombre === emptyName,
    );
    expect(empty).toMatchObject({ pendientes: 0, edadCriticaMasAntiguaSegundos: null });
    const jobs = await queue.boss.fetch(name, {
      batchSize: 1,
      priority: true,
      includeMetadata: true,
    });
    expect(await find()).toMatchObject({ pendientes: 3, activas: 1 });
    await queue.boss.fail(name, jobs[0]!.id, { motivo: 'fallo sintético' });
    expect(await find()).toMatchObject({ pendientes: 3, activas: 0, fallidas: 1 });
    expect(JSON.stringify((await metrics().expect(200)).body)).not.toContain('NO_REGISTRAR');
  });

  it('un 500 conserva correlación sin registrar el texto sensible de una excepción', async () => {
    const logger = vi.spyOn(Logger.prototype, 'error');
    vi.spyOn(app.get<OutboxWriter>(OUTBOX_WRITER), 'record').mockRejectedValueOnce(
      new Error('SECRETO_NO_REGISTRAR'),
    );
    const response = await request(server())
      .post('/v1/publicaciones')
      .auth(neighbor, { type: 'bearer' })
      .set('Idempotency-Key', newId())
      .set('x-request-id', 'fallo-controlado')
      .send({ id: newId(), tipo: 'presto', categoria: 'agua', titulo: 'Prueba de rollback' })
      .expect(500);
    expect(response.body).toMatchObject({ requestId: 'fallo-controlado', codigo: 'error_interno' });
    expect(JSON.stringify(logger.mock.calls)).not.toContain('SECRETO_NO_REGISTRAR');
  });
});
