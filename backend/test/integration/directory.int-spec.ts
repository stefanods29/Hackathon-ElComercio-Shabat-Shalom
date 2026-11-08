import type { INestApplication } from '@nestjs/common';
import { type Kysely, sql } from 'kysely';
import request from 'supertest';
import { inject } from 'vitest';
import { DEMO_SERVICES, NEIGHBORS, NEIGHBOR_ZONE, PILOT_ZONE } from '../../scripts/seed-data.js';
import { createKysely } from '../../src/shared/db/connection.js';
import { newId } from '../../src/shared/domain/ids.js';
import { OUTBOX_WRITER, type OutboxWriter } from '../../src/shared/outbox/outbox.js';
import { JobHandlerRegistry } from '../../src/shared/queues/job-handler.registry.js';
import { InMemoryJobQueue } from '../../src/shared/queues/job-queue.memory.js';
import { createTestApp } from '../support/app.js';

describe('Directorio por HTTP con PostgreSQL', () => {
  let app: INestApplication;
  let db: Kysely<unknown>;
  let queue: InMemoryJobQueue;
  let sequence = 0;
  const tokens: Record<string, string> = {};
  const server = () => app.getHttpServer();
  const body = (id = newId()) => ({
    id,
    categoriaId: 'gasfiteria',
    titulo: 'Gasfitero a domicilio',
    descripcion: 'Arreglo fugas y cambio caños',
    ubicacion: { lat: -12.085678, lng: -77.034567 },
  });
  const signIn = async (phone: string) => {
    const response = await request(server())
      .post('/v1/dev/sesiones')
      .send({ telefono: phone })
      .expect(201);
    return response.body.tokenDeAcceso as string;
  };
  const saveProfile = (token: string, name = 'Gasfitería de prueba', key = newId()) =>
    request(server())
      .put('/v1/yo/proveedor')
      .auth(token, { type: 'bearer' })
      .set('Idempotency-Key', key)
      .send({ nombrePublico: name });
  const publish = (token: string, data: Record<string, unknown> = body(), key = newId()) =>
    request(server())
      .post('/v1/servicios')
      .auth(token, { type: 'bearer' })
      .set('Idempotency-Key', key)
      .send(data);
  const editBody = (version = 1) => {
    const { id: _id, ...data } = body();
    return { ...data, versionVista: version };
  };
  const edit = (id: string, token: string, version = 1, key = newId()) =>
    request(server())
      .put(`/v1/servicios/${id}`)
      .auth(token, { type: 'bearer' })
      .set('Idempotency-Key', key)
      .send(editBody(version));
  const withdraw = (id: string, token: string, key = newId()) =>
    request(server())
      .delete(`/v1/servicios/${id}`)
      .auth(token, { type: 'bearer' })
      .set('Idempotency-Key', key);
  const readProfile = (id: string, token: string) =>
    request(server()).get(`/v1/proveedores/${id}`).auth(token, { type: 'bearer' });

  async function neighbor(zoneId: string | null = PILOT_ZONE.id) {
    const id = newId();
    const phone = `+5191810${String(++sequence).padStart(4, '0')}`;
    await sql`
      INSERT INTO identidad.usuarios (id, telefono, nombre_visible, zona_id, nivel_confianza, roles)
      VALUES (${id}, ${phone}, 'Vecino de prueba de directorio', ${zoneId}, 1, '{}'::text[])
    `.execute(db);
    return { id, phone, token: await signIn(phone) };
  }

  async function provider() {
    const owner = await neighbor();
    await saveProfile(owner.token).expect(200);
    return owner;
  }

  async function publicationCount(id: string): Promise<number> {
    const { rows } = await sql<{ count: number }>`
      SELECT count(*)::int AS count FROM compartido.outbox
      WHERE agregado_id = ${id} AND tipo = 'directorio.servicio_publicado'
    `.execute(db);
    return rows[0]!.count;
  }

  beforeAll(async () => {
    ({ app } = await createTestApp(inject('databaseUrl')));
    await app.listen(0, '127.0.0.1');
    db = createKysely(inject('databaseUrl'), 4);
    queue = new InMemoryJobQueue();
    await app.get(JobHandlerRegistry).startAll(queue);
    for (const name of ['beto', 'dario', 'elena'] as const) {
      tokens[name] = await signIn(NEIGHBORS[name].phone);
    }
  });
  afterEach(() => vi.restoreAllMocks());
  afterAll(async () => {
    await app?.close();
    await db?.destroy();
  });

  it('lista categorías sembradas con id estable, ícono y utilidad en emergencia', async () => {
    await request(server()).get('/v1/categorias').expect(401);
    const response = await request(server())
      .get('/v1/categorias')
      .auth(tokens.dario!, { type: 'bearer' })
      .expect(200);
    expect(response.body.datos).toContainEqual({
      id: 'gasfiteria',
      nombre: 'Gasfitería',
      icono: 'plumbing',
      utilEnEmergencia: true,
      orden: 10,
    });
    const orders = response.body.datos.map((category: { orden: number }) => category.orden);
    expect(orders).toEqual([...orders].sort((left: number, right: number) => left - right));
  });

  it('guarda y actualiza el perfil propio, exige nivel 1 y zona y repite la cabecera', async () => {
    const owner = await neighbor();
    const key = newId();
    const first = await saveProfile(owner.token, 'Gasfitería Luis', key).expect(200);
    expect(first.body).toMatchObject({ id: owner.id, nombrePublico: 'Gasfitería Luis' });
    const replay = await saveProfile(owner.token, 'Gasfitería Luis', key).expect(200);
    expect(replay.headers['idempotent-replayed']).toBe('true');
    expect(replay.body).toEqual(first.body);
    await saveProfile(owner.token, 'Nuevo perfil').expect(200);
    const saved = await readProfile(owner.id, owner.token).expect(200);
    expect(saved.body.nombrePublico).toBe('Nuevo perfil');
    expect((await saveProfile(tokens.dario!).expect(403)).body.codigo).toBe(
      'nivel_de_confianza_insuficiente',
    );
    const withoutZone = await neighbor(null);
    expect((await saveProfile(withoutZone.token).expect(403)).body.codigo).toBe('sin_zona');
    expect((await publish(withoutZone.token).expect(403)).body.codigo).toBe('sin_zona');
    expect((await publish(tokens.dario!).expect(403)).body.codigo).toBe(
      'nivel_de_confianza_insuficiente',
    );
  });

  it('publica 201 o 200 con el mismo id propio y guarda un solo evento', async () => {
    const owner = await provider();
    const data = body();
    const key = newId();
    const first = await publish(owner.token, data, key).expect(201);
    expect(first.body).toMatchObject({ id: data.id, proveedorId: owner.id, version: 1 });
    const replay = await publish(owner.token, data, key).expect(200);
    expect(replay.headers['idempotent-replayed']).toBe('true');
    expect(replay.body).toEqual(first.body);
    const retry = await publish(owner.token, { ...data, titulo: 'No se debe sobrescribir' }).expect(
      200,
    );
    expect(retry.body).toEqual(first.body);
    expect(await publicationCount(data.id)).toBe(1);
    const collision = await publish(tokens.beto!, data).expect(409);
    expect(collision.body.codigo).toBe('id_en_uso');
    expect(collision.body).not.toHaveProperty('titulo');
  });

  it('guarda la ubicación exacta privada y solo publica la copia redondeada', async () => {
    const owner = await provider();
    const published = await publish(owner.token).expect(201);
    expect(published.body.ubicacion).toEqual({ lat: -12.086, lng: -77.035 });
    const { rows } = await sql<{
      lat: number;
      lng: number;
      lat_publica: number;
      lng_publica: number;
    }>`SELECT ST_Y(ubicacion::geometry) AS lat, ST_X(ubicacion::geometry) AS lng,
              lat_publica, lng_publica FROM directorio.servicios WHERE id = ${published.body.id}`.execute(
      db,
    );
    expect(rows[0]).toEqual({
      lat: -12.085678,
      lng: -77.034567,
      lat_publica: -12.086,
      lng_publica: -77.035,
    });
    const profile = await readProfile(owner.id, tokens.elena!).expect(200);
    expect(Object.keys(profile.body).sort()).toEqual(
      ['id', 'nombrePublico', 'descripcion', 'actualizadoEn', 'servicios'].sort(),
    );
    expect(profile.body.servicios[0].ubicacion).toEqual({ lat: -12.086, lng: -77.035 });
    const serialized = JSON.stringify(profile.body);
    for (const privateValue of [
      owner.phone,
      '-12.085678',
      '-77.034567',
      'telefono',
      'private_lat',
    ]) {
      expect(serialized).not.toContain(privateValue);
    }
  });

  it('publica el punto exacto solo con aceptación y vuelve a redondear al editar sin ella', async () => {
    const owner = await provider();
    const published = await publish(owner.token, {
      ...body(),
      muestraUbicacionExacta: true,
    }).expect(201);
    expect(published.body.ubicacion).toEqual(body().ubicacion);
    const edited = await edit(published.body.id, owner.token).expect(200);
    expect(edited.body.ubicacion).toEqual({ lat: -12.086, lng: -77.035 });
    const { rows } = await sql<{ accepted: boolean }>`
      SELECT muestra_ubicacion_exacta AS accepted FROM directorio.servicios WHERE id = ${published.body.id}
    `.execute(db);
    expect(rows[0]?.accepted).toBe(false);
  });

  it('edita solo el dueño, incrementa versión y explica un conflicto con ambas versiones', async () => {
    const owner = await provider();
    const published = await publish(owner.token).expect(201);
    expect((await edit(published.body.id, tokens.beto!).expect(403)).body.codigo).toBe(
      'no_eres_el_dueno',
    );
    const key = newId();
    const updated = await edit(published.body.id, owner.token, 1, key).expect(200);
    expect(updated.body.version).toBe(2);
    const replay = await edit(published.body.id, owner.token, 1, key).expect(200);
    expect(replay.body).toEqual(updated.body);
    const conflict = await edit(published.body.id, owner.token).expect(409);
    expect(conflict.body).toMatchObject({
      codigo: 'conflicto_de_version',
      versionEsperada: 1,
      versionActual: 2,
    });
    await edit(newId(), owner.token).expect(404);
  });

  it('retira con 204 aunque ya esté retirado y nunca resucita por reintentar la publicación', async () => {
    const owner = await provider();
    const data = body();
    await publish(owner.token, data).expect(201);
    expect((await withdraw(data.id, tokens.beto!).expect(403)).body.codigo).toBe(
      'no_eres_el_dueno',
    );
    const key = newId();
    const first = await withdraw(data.id, owner.token, key).expect(204);
    expect(first.text).toBe('');
    await withdraw(data.id, owner.token).expect(204);
    const replay = await withdraw(data.id, owner.token, key).expect(200);
    expect(replay.headers['idempotent-replayed']).toBe('true');
    const retry = await publish(owner.token, data).expect(200);
    expect(retry.body).toMatchObject({ version: 2, eliminadoEn: expect.any(String) });
    expect((await edit(data.id, owner.token, 2).expect(409)).body.codigo).toBe('servicio_retirado');
    expect((await readProfile(owner.id, owner.token).expect(200)).body.servicios).toEqual([]);
    expect(await publicationCount(data.id)).toBe(1);
    await withdraw(newId(), owner.token).expect(404);
  });

  it('omite servicios ocultos y rechaza perfiles ocultos o eliminados', async () => {
    const owner = await provider();
    const published = await publish(owner.token).expect(201);
    await sql`UPDATE directorio.servicios SET oculto_en = now() WHERE id = ${published.body.id}`.execute(
      db,
    );
    expect((await readProfile(owner.id, owner.token).expect(200)).body.servicios).toEqual([]);
    await sql`UPDATE directorio.proveedores SET oculto_en = now() WHERE id = ${owner.id}`.execute(
      db,
    );
    await readProfile(owner.id, owner.token).expect(404);
    await sql`UPDATE directorio.proveedores SET oculto_en = NULL, eliminado_en = now() WHERE id = ${owner.id}`.execute(
      db,
    );
    await readProfile(owner.id, owner.token).expect(404);
    await readProfile(newId(), owner.token).expect(404);
  });

  it('reintentos concurrentes crean un solo servicio y un id ajeno tiene un único ganador', async () => {
    const owner = await provider();
    const data = body();
    const results = await Promise.all(Array.from({ length: 5 }, () => publish(owner.token, data)));
    expect(results.map((result) => result.status).sort()).toEqual([200, 200, 200, 200, 201]);
    expect(await publicationCount(data.id)).toBe(1);
    const other = await provider();
    const sharedId = body();
    const race = await Promise.all([
      publish(owner.token, sharedId),
      publish(other.token, sharedId),
    ]);
    expect(race.map((result) => result.status).sort()).toEqual([201, 409]);
    expect(race.find((result) => result.status === 409)?.body.codigo).toBe('id_en_uso');
    expect(await publicationCount(sharedId.id)).toBe(1);
  });

  it('dos ediciones con versión 1 tienen un solo ganador y dos retiros terminan en 204', async () => {
    const owner = await provider();
    const published = await publish(owner.token).expect(201);
    const edits = await Promise.all([
      edit(published.body.id, owner.token),
      edit(published.body.id, owner.token),
    ]);
    expect(edits.map((result) => result.status).sort()).toEqual([200, 409]);
    expect(edits.find((result) => result.status === 409)?.body.codigo).toBe('conflicto_de_version');
    const withdrawals = await Promise.all([
      withdraw(published.body.id, owner.token),
      withdraw(published.body.id, owner.token),
    ]);
    expect(withdrawals.map((result) => result.status)).toEqual([204, 204]);
  });

  it('un fallo del outbox revierte el INSERT y permite reintentar la misma clave', async () => {
    const owner = await provider();
    const data = body();
    const key = newId();
    vi.spyOn(app.get<OutboxWriter>(OUTBOX_WRITER), 'record').mockRejectedValueOnce(
      new Error('fallo simulado'),
    );
    await publish(owner.token, data, key).expect(500);
    const { rows } = await sql<{ count: number }>`
      SELECT count(*)::int AS count FROM directorio.servicios WHERE id = ${data.id}
    `.execute(db);
    expect(rows[0]?.count).toBe(0);
    expect(await publicationCount(data.id)).toBe(0);
    await publish(owner.token, data, key).expect(201);
    expect(await publicationCount(data.id)).toBe(1);
  });

  it('el evento de zona retira solo lo anterior y su reintento conserva los servicios nuevos', async () => {
    const owner = await provider();
    const previous = [body(), body()];
    for (const service of previous) await publish(owner.token, service).expect(201);
    await sql`UPDATE identidad.usuarios SET zona_id = ${NEIGHBOR_ZONE.id} WHERE id = ${owner.id}`.execute(
      db,
    );
    const newToken = await signIn(owner.phone);
    await saveProfile(newToken).expect(200);
    const current = body();
    await publish(newToken, current).expect(201);
    const event = {
      eventoId: newId(),
      modulo: 'identidad',
      agregadoId: owner.id,
      ocurridoEn: '2026-11-08T01:00:00Z',
      carga: { zonaAnteriorId: PILOT_ZONE.id, zonaId: NEIGHBOR_ZONE.id },
    };
    for (let attempt = 0; attempt < 2; attempt += 1) {
      await queue.enqueue('identidad.zona_cambiada', event);
      await queue.drain();
    }
    const { rows } = await sql<{ id: string; version: number; removed: boolean }>`
      SELECT id, version, eliminado_en IS NOT NULL AS removed FROM directorio.servicios
      WHERE proveedor_id = ${owner.id} ORDER BY id
    `.execute(db);
    for (const old of previous) {
      expect(rows.find((row) => row.id === old.id)).toMatchObject({ version: 2, removed: true });
    }
    expect(rows.find((row) => row.id === current.id)).toMatchObject({ version: 1, removed: false });
    const profile = await readProfile(owner.id, newToken).expect(200);
    expect(profile.body.servicios.map((service: { id: string }) => service.id)).toEqual([
      current.id,
    ]);
  });

  it('siembra servicios de demostración con copia pública aproximada', async () => {
    for (const demo of DEMO_SERVICES) {
      const profile = await readProfile(demo.providerId, tokens.beto!).expect(200);
      expect(profile.body.servicios).toContainEqual(expect.objectContaining({ id: demo.id }));
    }
  });

  it('exige sesión e Idempotency-Key en cada escritura y sesión en los perfiles', async () => {
    const owner = await provider();
    const id = newId();
    const routes = [
      ['put', '/v1/yo/proveedor', { nombrePublico: 'Proveedor' }],
      ['post', '/v1/servicios', body()],
      ['put', `/v1/servicios/${id}`, editBody()],
      ['delete', `/v1/servicios/${id}`, undefined],
    ] as const;
    for (const [method, path, payload] of routes) {
      await request(server())[method](path).send(payload).expect(401);
      const missing = await request(server())
        [method](path)
        .auth(owner.token, { type: 'bearer' })
        .send(payload)
        .expect(400);
      expect(missing.body.codigo).toBe('validacion');
    }
    await request(server()).get(`/v1/proveedores/${owner.id}`).expect(401);
  });

  it('valida UUIDv7, límites, atributos UTF-8, campos extra y categorías inexistentes', async () => {
    const owner = await provider();
    for (const changes of [
      { id: '01970000-0000-4000-8000-000000000111' },
      { titulo: 'a' },
      { ubicacion: { lat: 91, lng: -77 } },
      { radioCoberturaM: 20001 },
      { atributos: { texto: 'á'.repeat(2043) } },
      { atributos: [] },
      { proveedorId: NEIGHBORS.beto.id },
    ]) {
      const invalid = await publish(owner.token, { ...body(), ...changes }).expect(400);
      expect(invalid.body.codigo).toBe('validacion');
    }
    expect(
      (await publish(owner.token, { ...body(), categoriaId: 'inexistente' }).expect(422)).body
        .codigo,
    ).toBe('categoria_invalida');
    const missingProfile = await neighbor();
    await publish(missingProfile.token).expect(404);
    await edit('no-es-uuid', owner.token).expect(400);
    await withdraw('no-es-uuid', owner.token).expect(400);
    await readProfile('no-es-uuid', owner.token).expect(400);
  });
});
