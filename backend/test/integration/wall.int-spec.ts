import type { INestApplication } from '@nestjs/common';
import { type Kysely, sql } from 'kysely';
import request from 'supertest';
import { inject } from 'vitest';
import { NEIGHBORS, PILOT_ZONE } from '../../scripts/seed-data.js';
import { OTP_PROVIDER } from '../../src/modules/identidad/application/ports.js';
import { FakeOtpProvider } from '../../src/modules/identidad/infrastructure/fake-otp.provider.js';
import { createKysely } from '../../src/shared/db/connection.js';
import { newId } from '../../src/shared/domain/ids.js';
import { OUTBOX_WRITER, type OutboxWriter } from '../../src/shared/outbox/outbox.js';
import { createTestApp } from '../support/app.js';

describe('Muro: transiciones y límite diario por HTTP', () => {
  let app: INestApplication;
  let db: Kysely<unknown>;
  let provider: FakeOtpProvider;
  let sequence = 0;
  const tokens: Record<string, string> = {};
  const server = () => app.getHttpServer();
  const body = (id = newId()) => ({
    id,
    tipo: 'presto',
    categoria: 'agua',
    titulo: 'Presto bidones de agua',
  });
  const publish = (token: string, data = body(), key = newId()) =>
    request(server())
      .post('/v1/publicaciones')
      .auth(token, { type: 'bearer' })
      .set('Idempotency-Key', key)
      .send(data);
  const act = (
    id: string,
    action: 'cancelar' | 'resolver' | 'tomar',
    token: string,
    version: number,
    key = newId(),
  ) =>
    request(server())
      .post(`/v1/publicaciones/${id}/${action}`)
      .auth(token, { type: 'bearer' })
      .set('Idempotency-Key', key)
      .send({ versionVista: version });

  async function author(): Promise<{ token: string; id: string }> {
    const phone = `+5191600${String(++sequence).padStart(4, '0')}`;
    await request(server()).post('/v1/auth/otp').send({ telefono: phone }).expect(202);
    const session = await request(server())
      .post('/v1/auth/otp/verificar')
      .send({ telefono: phone, codigo: provider.lastCodeFor(phone) })
      .expect(200);
    await request(server())
      .put('/v1/yo/zona')
      .auth(session.body.tokenDeAcceso, { type: 'bearer' })
      .set('Idempotency-Key', newId())
      .send({ zonaId: PILOT_ZONE.id })
      .expect(200);
    await sql`UPDATE identidad.usuarios SET nivel_confianza = 1 WHERE id = ${session.body.usuario.id}`.execute(
      db,
    );
    const renewed = await request(server())
      .post('/v1/auth/refrescar')
      .send({ refreshToken: session.body.refreshToken })
      .expect(200);
    return { token: renewed.body.tokenDeAcceso, id: renewed.body.usuario.id };
  }

  async function events(id: string, type: string): Promise<number> {
    const { rows } = await sql<{
      count: number;
    }>`SELECT count(*)::int AS count FROM compartido.outbox WHERE agregado_id = ${id} AND tipo = ${type}`.execute(
      db,
    );
    return rows[0]!.count;
  }

  beforeAll(async () => {
    ({ app } = await createTestApp(inject('databaseUrl'), {
      MAX_POSTS_PER_DAY: '3',
      OTP_MAX_REQUESTS_PER_IP: '1000',
    }));
    // Listen once so simultaneous Supertest clients do not register repeated listen callbacks.
    await app.listen(0, '127.0.0.1');
    provider = app.get(OTP_PROVIDER) as FakeOtpProvider;
    db = createKysely(inject('databaseUrl'), 3);
    for (const neighbor of ['beto', 'carla', 'elena'] as const) {
      const response = await request(server())
        .post('/v1/dev/sesiones')
        .send({ telefono: NEIGHBORS[neighbor].phone })
        .expect(201);
      tokens[neighbor] = response.body.tokenDeAcceso;
    }
  });
  afterEach(() => vi.restoreAllMocks());
  afterAll(async () => {
    await app?.close();
    await db?.destroy();
  });

  it('cancelar es idempotente por cabecera y por dominio y produce un solo evento', async () => {
    const neighbor = await author();
    const post = await publish(neighbor.token).expect(201);
    const key = newId();
    const first = await act(post.body.id, 'cancelar', neighbor.token, 1, key).expect(200);
    expect(first.body).toMatchObject({ estado: 'cancelada', version: 2 });
    const replay = await act(post.body.id, 'cancelar', neighbor.token, 1, key).expect(200);
    expect(replay.headers['idempotent-replayed']).toBe('true');
    expect(replay.body).toEqual(first.body);
    expect((await act(post.body.id, 'cancelar', neighbor.token, 1).expect(200)).body).toEqual(
      first.body,
    );
    expect(await events(post.body.id, 'solidaridad.publicacion_cancelada')).toBe(1);
  });

  it('resolver permite autor o tomador y no vuelve a incrementar versión ni outbox', async () => {
    const neighbor = await author();
    for (const resolver of [neighbor.token, tokens.beto!]) {
      const post = await publish(neighbor.token).expect(201);
      await act(post.body.id, 'tomar', tokens.beto!, 1).expect(200);
      const key = newId();
      const first = await act(post.body.id, 'resolver', resolver, 2, key).expect(200);
      expect(first.body).toMatchObject({
        estado: 'resuelta',
        version: 3,
        tomadaPorId: NEIGHBORS.beto.id,
      });
      const replay = await act(post.body.id, 'resolver', resolver, 2, key).expect(200);
      expect(replay.headers['idempotent-replayed']).toBe('true');
      expect(replay.body).toEqual(first.body);
      expect((await act(post.body.id, 'resolver', resolver, 2).expect(200)).body).toEqual(
        first.body,
      );
      expect(await events(post.body.id, 'solidaridad.favor_resuelto')).toBe(1);
    }
  });

  it('protege autoría, participación, zona y existencia sin modificar el favor', async () => {
    const neighbor = await author();
    const post = await publish(neighbor.token).expect(201);
    expect((await act(post.body.id, 'cancelar', tokens.beto!, 1).expect(403)).body.codigo).toBe(
      'no_eres_el_autor',
    );
    expect((await act(post.body.id, 'resolver', tokens.carla!, 1).expect(403)).body.codigo).toBe(
      'no_participas_en_este_favor',
    );
    for (const action of ['cancelar', 'resolver'] as const) {
      expect((await act(post.body.id, action, tokens.elena!, 1).expect(403)).body.codigo).toBe(
        'fuera_de_tu_zona',
      );
      await act(newId(), action, neighbor.token, 1).expect(404);
    }
    expect(await events(post.body.id, 'solidaridad.publicacion_cancelada')).toBe(0);
    expect(await events(post.body.id, 'solidaridad.favor_resuelto')).toBe(0);
  });

  it('rechaza versiones viejas y estados incompatibles con 409 explicable', async () => {
    const neighbor = await author();
    const post = await publish(neighbor.token).expect(201);
    await sql`UPDATE solidaridad.publicaciones SET version = 2 WHERE id = ${post.body.id}`.execute(
      db,
    );
    const stale = await act(post.body.id, 'cancelar', neighbor.token, 1).expect(409);
    expect(stale.body).toMatchObject({ codigo: 'conflicto_de_version', versionActual: 2 });
    expect((await act(post.body.id, 'resolver', neighbor.token, 2).expect(409)).body.codigo).toBe(
      'favor_no_en_curso',
    );
    await act(post.body.id, 'tomar', tokens.beto!, 2).expect(200);
    expect((await act(post.body.id, 'cancelar', neighbor.token, 3).expect(409)).body).toMatchObject(
      { codigo: 'no_se_puede_cancelar', estadoActual: 'en_curso' },
    );
    expect((await act(post.body.id, 'resolver', neighbor.token, 2).expect(409)).body).toMatchObject(
      { codigo: 'conflicto_de_version', versionActual: 3 },
    );
  });

  it('dos cancelaciones concurrentes terminan en una sola transición', async () => {
    const neighbor = await author();
    const post = await publish(neighbor.token).expect(201);
    const results = await Promise.all([
      act(post.body.id, 'cancelar', neighbor.token, 1),
      act(post.body.id, 'cancelar', neighbor.token, 1),
    ]);
    expect(results.map((response) => response.status)).toEqual([200, 200]);
    expect(results.every((response) => response.body.version === 2)).toBe(true);
    expect(await events(post.body.id, 'solidaridad.publicacion_cancelada')).toBe(1);
  });

  it('autor y tomador resuelven en paralelo sin duplicar el evento', async () => {
    const neighbor = await author();
    const post = await publish(neighbor.token).expect(201);
    await act(post.body.id, 'tomar', tokens.beto!, 1).expect(200);
    const results = await Promise.all([
      act(post.body.id, 'resolver', neighbor.token, 2),
      act(post.body.id, 'resolver', tokens.beto!, 2),
    ]);
    expect(results.map((response) => response.status)).toEqual([200, 200]);
    expect(results.every((response) => response.body.version === 3)).toBe(true);
    expect(await events(post.body.id, 'solidaridad.favor_resuelto')).toBe(1);
  });

  it('tomar y cancelar en paralelo dejan un único ganador y el perdedor recibe 409', async () => {
    const neighbor = await author();
    const post = await publish(neighbor.token).expect(201);
    const results = await Promise.all([
      act(post.body.id, 'cancelar', neighbor.token, 1),
      act(post.body.id, 'tomar', tokens.beto!, 1),
    ]);
    expect(results.map((response) => response.status).sort((a, b) => a - b)).toEqual([200, 409]);
    expect(
      (await events(post.body.id, 'solidaridad.publicacion_cancelada')) +
        (await events(post.body.id, 'solidaridad.favor_tomado')),
    ).toBe(1);
  });

  it('la cuarta publicación da 429 y un reintento del id existente pasa con otra clave', async () => {
    const neighbor = await author();
    const first = body();
    const key = newId();
    await publish(neighbor.token, first, key).expect(201);
    await publish(neighbor.token).expect(201);
    await publish(neighbor.token).expect(201);
    const limited = await publish(neighbor.token).expect(429);
    expect(limited.body.codigo).toBe('limite_diario_alcanzado');
    expect(Number(limited.headers['retry-after'])).toBeGreaterThan(0);
    expect(Number(limited.headers['retry-after'])).toBe(limited.body.reintentarEnSegundos);
    await publish(neighbor.token, first, key).expect(200);
    await publish(neighbor.token, first).expect(200);
    expect(await events(first.id, 'solidaridad.publicacion_creada')).toBe(1);
  });

  it('serializa publicaciones concurrentes para no superar el límite', async () => {
    const neighbor = await author();
    const results = await Promise.all(Array.from({ length: 10 }, () => publish(neighbor.token)));
    expect(results.filter((response) => response.status === 201)).toHaveLength(3);
    expect(results.filter((response) => response.status === 429)).toHaveLength(7);
    const count = await sql<{
      count: number;
    }>`SELECT count(*)::int AS count FROM solidaridad.publicaciones WHERE autor_id = ${neighbor.id}`.execute(
      db,
    );
    expect(count.rows[0]?.count).toBe(3);
  });

  it('reintentos concurrentes de un mismo id crean una sola publicación y consumen una plaza', async () => {
    const neighbor = await author();
    const data = body();
    const results = await Promise.all(
      Array.from({ length: 6 }, () => publish(neighbor.token, data)),
    );
    expect(results.filter((response) => response.status === 201)).toHaveLength(1);
    expect(results.filter((response) => response.status === 200)).toHaveLength(5);
    await publish(neighbor.token).expect(201);
    await publish(neighbor.token).expect(201);
    expect(await events(data.id, 'solidaridad.publicacion_creada')).toBe(1);
  });

  it('cancelar o eliminar no libera cuota y al vencer la ventana se puede reintentar el 429', async () => {
    const neighbor = await author();
    const posts = [];
    for (let index = 0; index < 3; index += 1)
      posts.push((await publish(neighbor.token).expect(201)).body.id as string);
    await act(posts[0]!, 'cancelar', neighbor.token, 1).expect(200);
    await sql`UPDATE solidaridad.publicaciones SET eliminado_en = now() WHERE id = ${posts[1]!}`.execute(
      db,
    );
    const pending = body();
    const key = newId();
    await publish(neighbor.token, pending, key).expect(429);
    await sql`UPDATE solidaridad.publicaciones SET creado_en = now() - interval '24 hours' - interval '1 second' WHERE id = ${posts[0]!}`.execute(
      db,
    );
    await publish(neighbor.token, pending, key).expect(201);
  });

  it('outbox y cambio de estado se revierten juntos cuando falla el registro del evento', async () => {
    const neighbor = await author();
    const post = await publish(neighbor.token).expect(201);
    const key = newId();
    vi.spyOn(app.get<OutboxWriter>(OUTBOX_WRITER), 'record').mockRejectedValueOnce(
      new Error('fallo simulado de outbox'),
    );
    await act(post.body.id, 'cancelar', neighbor.token, 1, key).expect(500);
    const saved = await sql<{
      estado: string;
      version: number;
    }>`SELECT estado, version FROM solidaridad.publicaciones WHERE id = ${post.body.id}`.execute(
      db,
    );
    expect(saved.rows).toEqual([{ estado: 'abierta', version: 1 }]);
    expect(await events(post.body.id, 'solidaridad.publicacion_cancelada')).toBe(0);
    await act(post.body.id, 'cancelar', neighbor.token, 1, key).expect(200);
  });

  it('valida cabecera, cuerpo y UUID en ambas transiciones', async () => {
    const neighbor = await author();
    const post = await publish(neighbor.token).expect(201);
    for (const action of ['cancelar', 'resolver'] as const) {
      await request(server())
        .post(`/v1/publicaciones/${post.body.id}/${action}`)
        .send({ versionVista: 1 })
        .expect(401);
      await request(server())
        .post(`/v1/publicaciones/${post.body.id}/${action}`)
        .auth(neighbor.token, { type: 'bearer' })
        .send({ versionVista: 1 })
        .expect(400);
      await act(post.body.id, action, neighbor.token, 0).expect(400);
      await act('no-es-uuid', action, neighbor.token, 1).expect(400);
    }
  });
});
