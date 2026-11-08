import type { INestApplication } from '@nestjs/common';
import { createHash } from 'node:crypto';
import { type Kysely, sql } from 'kysely';
import sharp from 'sharp';
import request from 'supertest';
import { v7 as uuidv7 } from 'uuid';
import { inject } from 'vitest';
import { NEIGHBORS } from '../../scripts/seed-data.js';
import { ProcessPhotos } from '../../src/modules/media/application/process-photos.js';
import {
  OBJECT_STORE,
  PHOTO_REPOSITORY,
  type PhotoRepository,
} from '../../src/modules/media/application/ports.js';
import type { FakeObjectStore } from '../../src/modules/media/infrastructure/object-store.fake.js';
import { photoKeys } from '../../src/modules/media/domain/photo.js';
import { KYSELY } from '../../src/shared/db/connection.js';
import { createTestApp } from '../support/app.js';

describe('Media: autorización, fotos reales y recuperación', () => {
  let app: INestApplication;
  let db: Kysely<unknown>;
  let storage: FakeObjectStore;
  let worker: ProcessPhotos;
  let repository: PhotoRepository;
  let jpeg: Buffer;
  const tokens: Record<string, string> = {};
  const server = () => app.getHttpServer();
  const headers = (user = 'ana') => ({
    Authorization: `Bearer ${tokens[user]}`,
    'Idempotency-Key': uuidv7(),
  });
  const body = (id = uuidv7(), bytes = jpeg) => ({
    id,
    tipoContenido: 'image/jpeg',
    bytes: bytes.length,
    sha256: createHash('sha256').update(bytes).digest('hex'),
  });
  const reserve = async (input = body(), user = 'ana') => {
    await request(server()).post('/v1/archivos').set(headers(user)).send(input).expect(200);
    return input.id;
  };
  const confirm = (id: string, user = 'ana') =>
    request(server()).post(`/v1/archivos/${id}/confirmar`).set(headers(user)).send({});
  beforeAll(async () => {
    ({ app } = await createTestApp(inject('databaseUrl'), { MEDIA_DRIVER: 'fake' }));
    db = app.get(KYSELY);
    storage = app.get(OBJECT_STORE);
    worker = app.get(ProcessPhotos);
    repository = app.get(PHOTO_REPOSITORY);
    jpeg = await sharp({ create: { width: 50, height: 30, channels: 3, background: 'blue' } })
      .jpeg()
      .toBuffer();
    for (const user of ['ana', 'beto'] as const) {
      const response = await request(server())
        .post('/v1/dev/sesiones')
        .send({ telefono: NEIGHBORS[user].phone })
        .expect(201);
      tokens[user] = response.body.tokenDeAcceso;
    }
  });
  beforeEach(async () => {
    await sql`TRUNCATE media.archivos`.execute(db);
    storage.objects.clear();
  });
  afterAll(async () => {
    await app?.close();
  });

  it('exige sesión, valida tamaños y no duplica un registro repetido', async () => {
    await request(server()).post('/v1/archivos').send(body()).expect(401);
    await request(server())
      .post('/v1/archivos')
      .set(headers())
      .send({ ...body(), bytes: 2097153 })
      .expect(400);
    const input = body();
    const auth = headers();
    const first = await request(server()).post('/v1/archivos').set(auth).send(input).expect(200);
    const retry = await request(server()).post('/v1/archivos').set(auth).send(input).expect(200);
    expect(retry.body).toEqual(first.body);
    await reserve(input);
    await request(server())
      .post('/v1/archivos')
      .set(headers())
      .send({ ...input, bytes: input.bytes + 1 })
      .expect(409);
  });
  it('no revela un archivo de otro vecino ni concede su subida o baja', async () => {
    const id = await reserve();
    await request(server()).get(`/v1/archivos/${id}`).set(headers('beto')).expect(404);
    for (const action of ['subida', 'confirmar', 'baja'])
      await request(server())
        .post(`/v1/archivos/${id}/${action}`)
        .set(headers('beto'))
        .send({})
        .expect(404);
    await request(server()).post('/v1/archivos').set(headers('beto')).send(body(id)).expect(404);
  });
  it('firma, confirma, procesa y solo devuelve enlaces privados temporales al dueño', async () => {
    const id = await reserve();
    const permission = await request(server())
      .post(`/v1/archivos/${id}/subida`)
      .set(headers())
      .send({})
      .expect(200);
    expect(permission.body.encabezados['If-None-Match']).toBe('*');
    expect(new Date(permission.body.venceEn).getTime() - Date.now()).toBeLessThanOrEqual(300000);
    await confirm(id).expect(409);
    storage.objects.set(photoKeys(id).original, { bytes: jpeg, contentType: 'image/jpeg' });
    await confirm(id).expect(200);
    await Promise.all([worker.next(), worker.next()]);
    const view = await request(server()).get(`/v1/archivos/${id}`).set(headers()).expect(200);
    expect(view.body).toMatchObject({ estado: 'listo', ancho: 50, alto: 30 });
    expect(view.body.miniaturaUrl).toContain('/miniatura.webp');
    expect(view.headers['cache-control']).toBe('no-store');
    expect(Object.keys(view.body)).not.toContain('propietario_id');
    await request(server()).get(`/v1/archivos/${id}`).set(headers('beto')).expect(404);
    await request(server()).post(`/v1/archivos/${id}/subida`).set(headers()).send({}).expect(409);
  });
  it('rechaza una huella falsa y una imagen corrupta aunque su MIME diga JPEG', async () => {
    for (const corrupt of [false, true]) {
      const uploaded = corrupt ? Buffer.from('contenido que no es imagen') : jpeg;
      const input = body(uuidv7(), uploaded);
      if (!corrupt) input.sha256 = '0'.repeat(64);
      const id = await reserve(input);
      storage.objects.set(photoKeys(id).original, { bytes: uploaded, contentType: 'image/jpeg' });
      await confirm(id).expect(200);
      while (await worker.next()) {
        /* Drain processing and eligible cleanup. */
      }
      const view = await request(server()).get(`/v1/archivos/${id}`).set(headers()).expect(200);
      expect(view.body.estado).toBe('rechazado');
      expect(view.body.motivo).toBe(corrupt ? 'imagen_invalida' : 'contenido_distinto');
      expect(view.body.url).toBeUndefined();
    }
  });
  it('recupera un arrendamiento vencido y el trabajador antiguo no puede completar', async () => {
    const id = await reserve();
    storage.objects.set(photoKeys(id).original, { bytes: jpeg, contentType: 'image/jpeg' });
    await confirm(id).expect(200);
    const old = await repository.claim();
    expect(old).not.toBeNull();
    await sql`UPDATE media.archivos SET arrendado_hasta = now() - interval '1 second' WHERE id = ${id}::uuid`.execute(
      db,
    );
    await worker.next();
    const accepted = await repository.finish(old!, {
      image: jpeg,
      thumbnail: jpeg,
      width: 1,
      height: 1,
      blurhash: 'no',
    });
    expect(accepted).toBe(false);
    expect((await repository.findOwned(id, NEIGHBORS.ana.id))?.state).toBe('listo');
  });
  it('retira el archivo y limpia objetos después de vencer las URLs de subida', async () => {
    const id = await reserve();
    storage.objects.set(photoKeys(id).original, { bytes: jpeg, contentType: 'image/jpeg' });
    await request(server()).post(`/v1/archivos/${id}/subida`).set(headers()).send({}).expect(200);
    await request(server()).post(`/v1/archivos/${id}/baja`).set(headers()).send({}).expect(200);
    await request(server()).get(`/v1/archivos/${id}`).set(headers()).expect(404);
    expect(await worker.next()).toBe(false);
    expect(storage.objects.size).toBe(1);
    await sql`UPDATE media.archivos SET limpiar_despues = now() - interval '1 second' WHERE id = ${id}::uuid`.execute(
      db,
    );
    await worker.next();
    expect(storage.objects.size).toBe(0);
    await request(server()).post(`/v1/archivos/${id}/baja`).set(headers()).send({}).expect(200);
  });
  it('aplica la cuota por cuenta incluso con reservas concurrentes', async () => {
    for (let batch = 0; batch < 4; batch++)
      await Promise.all(Array.from({ length: 5 }, () => reserve()));
    await request(server()).post('/v1/archivos').set(headers()).send(body()).expect(422);
  });
});
