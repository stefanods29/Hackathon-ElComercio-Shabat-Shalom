import type { INestApplication } from '@nestjs/common';
import { type Kysely, sql } from 'kysely';
import request from 'supertest';
import { inject } from 'vitest';
import { DEMO_SERVICES, NEIGHBORS, NEIGHBOR_ZONE, PILOT_ZONE } from '../../scripts/seed-data.js';
import { OTP_PROVIDER } from '../../src/modules/identidad/application/ports.js';
import type { FakeOtpProvider } from '../../src/modules/identidad/infrastructure/fake-otp.provider.js';
import { REVIEW_PHOTO_READER } from '../../src/modules/reputacion/index.js';
import { InMemoryReviewPhotoReader } from '../../src/modules/reputacion/infrastructure/review-photo.reader.memory.js';
import { createKysely } from '../../src/shared/db/connection.js';
import { CLOCK } from '../../src/shared/domain/clock.js';
import { newId } from '../../src/shared/domain/ids.js';
import type { OutboxJob } from '../../src/shared/outbox/outbox-relay.js';
import { OUTBOX_WRITER, type OutboxWriter } from '../../src/shared/outbox/outbox.js';
import { JobHandlerRegistry } from '../../src/shared/queues/job-handler.registry.js';
import { InMemoryJobQueue } from '../../src/shared/queues/job-queue.memory.js';
import { createTestApp } from '../support/app.js';

const NOW = new Date('2026-11-08T03:00:00Z');
const CREATED = 'reputacion.resena_creada';
const RECALCULATE = 'reputacion.recalculo_solicitado';
const AGGREGATES = 'reputacion.agregados_recalculados';
const SEED_SERVICE = DEMO_SERVICES[0].id;

interface NeighborOptions {
  ageHours?: number;
  trustLevel?: number;
  zoneId?: string | null;
  device?: string;
}

interface AggregateRow {
  total_resenas: number;
  suma_calificaciones: number;
  promedio: string;
  puntaje_ranking: string;
  total_vistos_buenos: number;
  vistos_buenos_de_la_zona: number;
  version: number;
}

describe('Reseñas, Visto Bueno y ranking con PostgreSQL', () => {
  let app: INestApplication;
  let db: Kysely<unknown>;
  let queue: InMemoryJobQueue;
  let now = NOW;
  let sequence = 0;
  const clock = { now: () => now };
  const photos = new InMemoryReviewPhotoReader();
  const tokens: Record<string, string> = {};
  const server = () => app.getHttpServer();
  const body = (serviceId: string = SEED_SERVICE) => ({
    id: newId(),
    servicioId: serviceId,
    calificacion: 5,
  });
  const write = (token: string, data: Record<string, unknown> = body(), key = newId()) =>
    request(server())
      .post('/v1/resenas')
      .auth(token, { type: 'bearer' })
      .set('Idempotency-Key', key)
      .send(data);
  const give = (token: string, serviceId: string, key = newId()) =>
    request(server())
      .post(`/v1/servicios/${serviceId}/visto-bueno`)
      .auth(token, { type: 'bearer' })
      .set('Idempotency-Key', key);
  const withdraw = (token: string, serviceId: string, key = newId()) =>
    request(server())
      .delete(`/v1/servicios/${serviceId}/visto-bueno`)
      .auth(token, { type: 'bearer' })
      .set('Idempotency-Key', key);

  async function devSignIn(phone: string): Promise<string> {
    const response = await request(server())
      .post('/v1/dev/sesiones')
      .send({ telefono: phone })
      .expect(201);
    return response.body.tokenDeAcceso as string;
  }

  async function neighbor(options: NeighborOptions = {}) {
    const id = newId();
    const phone = `+5191830${String(++sequence).padStart(4, '0')}`;
    const zoneId = options.zoneId === undefined ? PILOT_ZONE.id : options.zoneId;
    const createdAt = new Date(now.getTime() - (options.ageHours ?? 96) * 3_600_000);
    await sql`
      INSERT INTO identidad.usuarios (id, telefono, nombre_visible, zona_id, nivel_confianza, roles, creado_en)
      VALUES (${id}, ${phone}, 'Vecino de prueba de reputación', ${zoneId}, ${options.trustLevel ?? 1}, '{}'::text[], ${createdAt})
    `.execute(db);
    if (!options.device) return { id, phone, token: await devSignIn(phone) };
    const otp = app.get<FakeOtpProvider>(OTP_PROVIDER);
    await request(server()).post('/v1/auth/otp').send({ telefono: phone }).expect(202);
    const response = await request(server())
      .post('/v1/auth/otp/verificar')
      .send({
        telefono: phone,
        codigo: otp.lastCodeFor(phone),
        dispositivo: options.device,
      })
      .expect(200);
    return { id, phone, token: response.body.tokenDeAcceso as string };
  }

  async function createService(categoryId = 'gasfiteria'): Promise<string> {
    const id = newId();
    await sql`
      INSERT INTO directorio.servicios (id, proveedor_id, zona_id, categoria_id, titulo,
        ubicacion, lat_publica, lng_publica, creado_en, actualizado_en)
      VALUES (${id}, ${NEIGHBORS.beto.id}, ${PILOT_ZONE.id}, ${categoryId}, 'Servicio de prueba de reseñas',
        ST_SetSRID(ST_MakePoint(-77.034567, -12.085678), 4326)::geography,
        -12.086, -77.035, ${now}, ${now})
    `.execute(db);
    return id;
  }

  async function storedReview(
    serviceId: string,
    rating: number,
    state: 'en_revision' | 'publicada' | 'oculta',
  ): Promise<void> {
    const user = await neighbor();
    await sql`
      INSERT INTO reputacion.resenas (id, servicio_id, autor_id, zona_autor_id, calificacion, estado,
        creado_en, actualizado_en, publicada_en)
      VALUES (${newId()}, ${serviceId}, ${user.id}, ${PILOT_ZONE.id}, ${rating}, ${state}, ${now}, ${now},
        ${state === 'publicada' ? now : null})
    `.execute(db);
  }

  async function events(type: string, aggregateId: string): Promise<OutboxJob[]> {
    const { rows } = await sql<{
      id: string;
      modulo: string;
      agregado_id: string;
      carga: unknown;
      ocurrido_en: Date;
    }>`
      SELECT id, modulo, agregado_id, carga, ocurrido_en FROM compartido.outbox
      WHERE tipo = ${type} AND agregado_id = ${aggregateId} ORDER BY ocurrido_en, id
    `.execute(db);
    return rows.map((row) => ({
      eventoId: row.id,
      modulo: row.modulo,
      agregadoId: row.agregado_id,
      carga: row.carga,
      ocurridoEn: row.ocurrido_en.toISOString(),
    }));
  }

  async function deliver(type: string, job: unknown): Promise<void> {
    await queue.enqueue(type, job);
    await queue.drain();
  }

  async function project(serviceId: string): Promise<OutboxJob> {
    const requestJob = (await events(RECALCULATE, serviceId)).at(-1) ?? {
      agregadoId: serviceId,
      carga: { servicioId: serviceId },
    };
    await deliver(RECALCULATE, requestJob);
    const result = (await events(AGGREGATES, serviceId)).at(-1)!;
    await deliver(AGGREGATES, result);
    return result;
  }

  async function aggregates(serviceId: string): Promise<AggregateRow> {
    const { rows } = await sql<AggregateRow>`
      SELECT total_resenas, suma_calificaciones, promedio, puntaje_ranking,
        total_vistos_buenos, vistos_buenos_de_la_zona, version
      FROM directorio.servicios WHERE id = ${serviceId}
    `.execute(db);
    return rows[0]!;
  }

  beforeAll(async () => {
    ({ app } = await createTestApp(
      inject('databaseUrl'),
      {
        MAX_REVIEWS_PER_DAY: '2',
        OTP_MAX_REQUESTS_PER_IP: '1000',
      },
      (builder) =>
        builder
          .overrideProvider(CLOCK)
          .useValue(clock)
          .overrideProvider(REVIEW_PHOTO_READER)
          .useValue(photos),
    ));
    await app.listen(0, '127.0.0.1');
    db = createKysely(inject('databaseUrl'), 4);
    queue = new InMemoryJobQueue(clock);
    await app.get(JobHandlerRegistry).startAll(queue);
    for (const name of ['beto', 'dario', 'elena'] as const)
      tokens[name] = await devSignIn(NEIGHBORS[name].phone);
  });
  beforeEach(() => {
    now = NOW;
  });
  afterEach(() => vi.restoreAllMocks());
  afterAll(async () => {
    await app?.close();
    await db?.destroy();
  });

  it('crea 201 en revisión y devuelve 200 por clave o id propio con un solo evento', async () => {
    const author = await neighbor();
    const input = { ...body(), comentario: '  Muy puntual  ' };
    const key = newId();
    const created = await write(author.token, input, key).expect(201);
    expect(created.body).toMatchObject({
      id: input.id,
      servicioId: SEED_SERVICE,
      calificacion: 5,
      estado: 'en_revision',
      motivoEstado: null,
      publicadaEn: null,
      comentario: 'Muy puntual',
      fotos: [],
    });
    const replay = await write(author.token, input, key).expect(200);
    expect(replay.headers['idempotent-replayed']).toBe('true');
    expect(replay.body).toEqual(created.body);
    expect(
      (await write(author.token, { ...input, calificacion: 1 }, key).expect(422)).body.codigo,
    ).toBe('idempotency_key_reutilizada');
    expect((await write(author.token, { ...input, calificacion: 1 }).expect(200)).body).toEqual(
      created.body,
    );
    const recorded = await events(CREATED, input.id);
    expect(recorded).toHaveLength(1);
    expect(recorded[0]?.carga).toEqual({ servicioId: SEED_SERVICE, autorId: author.id });
    expect((await write(author.token, body()).expect(409)).body.codigo).toBe('resena_duplicada');
    expect((await write((await neighbor()).token, input).expect(409)).body.codigo).toBe(
      'id_en_uso',
    );
  });

  it('protege nivel, autoría, zona, vigencia del servicio y edad de la cuenta', async () => {
    const author = await neighbor();
    expect((await write(tokens.dario!).expect(403)).body.codigo).toBe(
      'nivel_de_confianza_insuficiente',
    );
    expect((await write(tokens.beto!).expect(403)).body.codigo).toBe('no_puedes_resenarte');
    expect((await write(tokens.elena!).expect(403)).body.codigo).toBe('fuera_de_tu_zona');
    expect((await write((await neighbor({ zoneId: null })).token).expect(403)).body.codigo).toBe(
      'sin_zona',
    );
    expect((await write((await neighbor({ ageHours: 1 })).token).expect(403)).body.codigo).toBe(
      'cuenta_muy_nueva',
    );
    await write(author.token, body(newId())).expect(404);
    const inactive = await createService();
    await sql`UPDATE directorio.servicios SET eliminado_en = ${now} WHERE id = ${inactive}`.execute(
      db,
    );
    await write(author.token, body(inactive)).expect(404);
    expect((await give(tokens.beto!, SEED_SERVICE).expect(403)).body.codigo).toBe(
      'no_puedes_resenarte',
    );
    expect((await give(tokens.elena!, SEED_SERVICE).expect(403)).body.codigo).toBe(
      'fuera_de_tu_zona',
    );
    await give(author.token, inactive).expect(404);
  });

  it('serializa la cuota ante envíos simultáneos y 429 incluye Retry-After', async () => {
    const author = await neighbor();
    const services = [await createService(), await createService(), await createService()];
    const input = services.map((service) => body(service));
    const results = await Promise.all(input.map((data) => write(author.token, data)));
    expect(results.map((result) => result.status).sort()).toEqual([201, 201, 429]);
    const rejected = results.find((result) => result.status === 429)!;
    expect(rejected.body).toMatchObject({
      codigo: 'limite_diario_alcanzado',
      reintentarEnSegundos: 86400,
    });
    expect(rejected.headers['retry-after']).toBe('86400');
    const accepted = input[results.findIndex((result) => result.status === 201)]!;
    await write(author.token, accepted).expect(200);
    const counts = await Promise.all(
      input.map(async (data) => (await events(CREATED, data.id)).length),
    );
    expect(counts.sort()).toEqual([0, 1, 1]);
  });

  it('en dos reseñas simultáneas con distinto id del mismo autor y servicio solo una se guarda', async () => {
    const author = await neighbor();
    const results = await Promise.all([write(author.token), write(author.token)]);
    expect(results.map((result) => result.status).sort()).toEqual([201, 409]);
    expect(results.find((result) => result.status === 409)?.body.codigo).toBe('resena_duplicada');
  });

  it('rechaza la foto ajena y enlaza solo fotos listas propias sin publicar variantes', async () => {
    const author = await neighbor();
    const first = {
      id: newId(),
      ownerId: author.id,
      state: 'listo',
      purpose: 'resena',
      width: 320,
      height: 200,
      blurhash: 'demo',
    } as const;
    const second = { ...first, id: newId(), width: 640 };
    const foreign = { ...first, id: newId(), ownerId: newId() };
    for (const photo of [first, second, foreign]) photos.files.set(photo.id, photo);
    const bad = { ...body(), fotos: [first.id, foreign.id] };
    expect((await write(author.token, bad).expect(422)).body.codigo).toBe('archivo_no_valido');
    expect(await events(CREATED, bad.id)).toHaveLength(0);
    const good = { ...body(), fotos: [second.id, first.id] };
    const response = await write(author.token, good).expect(201);
    expect(response.body).toMatchObject({ fotos: good.fotos, estado: 'en_revision' });
    expect(JSON.stringify(response.body)).not.toMatch(/https?:\/\//);
    const { rows } = await sql<{ archivo_id: string; orden: number; ancho: number }>`
      SELECT archivo_id, orden, ancho FROM reputacion.resena_fotos WHERE resena_id = ${good.id} ORDER BY orden
    `.execute(db);
    expect(rows).toEqual([
      { archivo_id: second.id, orden: 0, ancho: 640 },
      { archivo_id: first.id, orden: 1, ancho: 320 },
    ]);
    const visible =
      await sql`SELECT f.id FROM reputacion.resena_fotos f JOIN reputacion.resenas r ON r.id = f.resena_id
      WHERE r.id = ${good.id} AND r.estado = 'publicada' AND f.oculta_en IS NULL`.execute(db);
    expect(visible.rows).toEqual([]);
  });

  it('revierte reseña, fotos y señal si falla el outbox y permite reintentar la misma clave', async () => {
    const author = await neighbor({ device: newId() });
    const fileId = newId();
    photos.files.set(fileId, {
      id: fileId,
      ownerId: author.id,
      purpose: 'resena',
      state: 'listo',
      width: 320,
      height: 200,
      blurhash: null,
    });
    const data = { ...body(), fotos: [fileId] };
    const key = newId();
    vi.spyOn(app.get<OutboxWriter>(OUTBOX_WRITER), 'record').mockRejectedValueOnce(
      new Error('fallo simulado'),
    );
    await write(author.token, data, key).expect(500);
    const { rows } = await sql<{ reviews: number; photos: number; signals: number }>`
      SELECT (SELECT count(*)::int FROM reputacion.resenas WHERE id = ${data.id}) AS reviews,
        (SELECT count(*)::int FROM reputacion.resena_fotos WHERE resena_id = ${data.id}) AS photos,
        (SELECT count(*)::int FROM reputacion.senales_resenas WHERE resena_id = ${data.id}) AS signals
    `.execute(db);
    expect(rows).toEqual([{ reviews: 0, photos: 0, signals: 0 }]);
    expect(await events(CREATED, data.id)).toHaveLength(0);
    await write(author.token, data, key).expect(201);
    expect(await events(CREATED, data.id)).toHaveLength(1);
  });

  it('Visto Bueno se conserva, solo suma al ranking desde nivel 2 y se retira sin duplicar trabajos', async () => {
    const serviceId = await createService();
    const levelOne = await neighbor();
    const levelTwo = await neighbor({ trustLevel: 2 });
    const original = await give(levelOne.token, serviceId).expect(200);
    expect(original.body).toMatchObject({ servicioId: serviceId, cuentaParaRanking: false });
    expect(original.body.id).toMatch(/^[0-9a-f-]{14}7/);
    expect((await give(levelOne.token, serviceId).expect(200)).body).toEqual(original.body);
    expect(await events(RECALCULATE, serviceId)).toHaveLength(1);
    await project(serviceId);
    expect(await aggregates(serviceId)).toMatchObject({
      total_vistos_buenos: 1,
      vistos_buenos_de_la_zona: 0,
    });
    expect((await give(levelTwo.token, serviceId).expect(200)).body.cuentaParaRanking).toBe(true);
    await project(serviceId);
    expect(await aggregates(serviceId)).toMatchObject({
      total_vistos_buenos: 2,
      vistos_buenos_de_la_zona: 1,
    });
    const key = newId();
    await withdraw(levelTwo.token, serviceId, key).expect(204);
    await withdraw(levelTwo.token, serviceId).expect(204);
    const replay = await withdraw(levelTwo.token, serviceId, key).expect(200);
    expect(replay.headers['idempotent-replayed']).toBe('true');
    expect(await events(RECALCULATE, serviceId)).toHaveLength(3);
    await project(serviceId);
    expect(await aggregates(serviceId)).toMatchObject({
      total_vistos_buenos: 1,
      vistos_buenos_de_la_zona: 0,
    });
  });

  it('recalcula desde reseñas publicadas, obtiene 37/9 y rechaza reenvíos viejos o duplicados', async () => {
    const category = `reputacion-${newId().slice(-12)}`;
    await sql`INSERT INTO directorio.categorias (id, nombre, icono, orden) VALUES (${category}, ${category}, 'plumbing', 1000)`.execute(
      db,
    );
    const target = await createService(category);
    const prior = await createService(category);
    for (const rating of [4, 4, 3]) await storedReview(prior, rating, 'publicada');
    await storedReview(target, 5, 'publicada');
    await storedReview(target, 4, 'publicada');
    await storedReview(target, 5, 'en_revision');
    await storedReview(target, 1, 'oculta');
    await project(prior);
    const first = await project(target);
    const latest = await project(target);
    expect(latest.carga).toEqual(first.carga);
    expect(latest.carga).toEqual({
      servicioId: target,
      totalResenas: 2,
      sumaCalificaciones: 9,
      totalVistosBuenos: 0,
      vistosBuenosDeLaZona: 0,
    });
    const row = await aggregates(target);
    expect(row).toMatchObject({
      total_resenas: 2,
      suma_calificaciones: 9,
      promedio: '4.50',
      version: 1,
    });
    expect(Number(row.puntaje_ranking)).toBeCloseTo(37 / 9, 4);
    expect(Number((await aggregates(prior)).puntaje_ranking)).toBe(3.9);
    await deliver(AGGREGATES, latest);
    await deliver(AGGREGATES, {
      ...latest,
      eventoId: newId(),
      ocurridoEn: new Date(now.getTime() - 1).toISOString(),
      carga: {
        servicioId: target,
        totalResenas: 1,
        sumaCalificaciones: 2,
        totalVistosBuenos: 0,
        vistosBuenosDeLaZona: 0,
      },
    });
    expect(await aggregates(target)).toEqual(row);
    const response = await request(server())
      .get('/v1/servicios')
      .auth(tokens.beto!, { type: 'bearer' })
      .query({ lat: -12.085678, lng: -77.034567, categoriaId: category })
      .expect(200);
    expect(response.body.datos[0]).toMatchObject({
      id: target,
      totalResenas: 2,
      puntajeRanking: 4.1111,
    });
  });

  it('cinco reseñas del mismo dispositivo en 24 horas abren un solo caso ante reintentos', async () => {
    const device = newId();
    const older = body();
    await write((await neighbor({ device })).token, older).expect(201);
    const outsideWindow = new Date(now.getTime() - 24 * 3_600_000);
    await sql`UPDATE reputacion.senales_resenas SET creado_en = ${outsideWindow} WHERE resena_id = ${older.id}`.execute(
      db,
    );
    await sql`UPDATE reputacion.resenas SET creado_en = ${outsideWindow} WHERE id = ${older.id}`.execute(
      db,
    );
    const reviewIds: string[] = [];
    for (let index = 0; index < 5; index += 1) {
      const author = await neighbor({ device, trustLevel: 2 });
      const data = body();
      await write(author.token, data).expect(201);
      reviewIds.push(data.id);
      const job = (await events(CREATED, data.id))[0]!;
      expect(JSON.stringify(job)).not.toContain(device);
      await deliver(CREATED, job);
      await deliver(CREATED, job);
    }
    const { rows } = await sql<{ contenido_id: string; estado: string; motivo: string }>`
      SELECT contenido_id, estado, motivo FROM moderacion.casos
      WHERE tipo_contenido = 'resena' AND contenido_id = ANY(${reviewIds}::uuid[])
    `.execute(db);
    expect(rows).toEqual([
      { contenido_id: reviewIds.at(-1), estado: 'pendiente', motivo: 'patron_de_resenas' },
    ]);
    const signals = await sql<{ dispositivo_hash: string }>`
      SELECT dispositivo_hash FROM reputacion.senales_resenas WHERE resena_id = ANY(${reviewIds}::uuid[])
    `.execute(db);
    expect(signals.rows).toHaveLength(5);
    expect(new Set(signals.rows.map((signal) => signal.dispositivo_hash)).size).toBe(1);
    expect(signals.rows[0]?.dispositivo_hash).toMatch(/^[0-9a-f]{64}$/);
  });

  it('valida sesión, clave, ids, calificación y fotos en los contratos de escritura', async () => {
    const author = await neighbor({ zoneId: NEIGHBOR_ZONE.id });
    for (const [method, path] of [
      ['post', '/v1/resenas'],
      ['post', `/v1/servicios/${SEED_SERVICE}/visto-bueno`],
      ['delete', `/v1/servicios/${SEED_SERVICE}/visto-bueno`],
    ] as const) {
      await request(server())[method](path).expect(401);
      await request(server())[method](path).auth(author.token, { type: 'bearer' }).expect(400);
    }
    for (const invalid of [
      { id: '01970000-0000-4000-8000-000000000111' },
      { servicioId: 'no-es-uuid' },
      { calificacion: 1.5 },
      { calificacion: 6 },
      { comentario: 'x'.repeat(2001) },
      { fotos: [newId(), newId(), newId(), newId()] },
    ]) {
      expect((await write(author.token, { ...body(), ...invalid }).expect(400)).body.codigo).toBe(
        'validacion',
      );
    }
    await give(author.token, 'invalido').expect(400);
    await withdraw(author.token, 'invalido').expect(400);
  });
});
