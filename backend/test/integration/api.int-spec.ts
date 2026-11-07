import type { INestApplication } from '@nestjs/common';
import { createLocalJWKSet, jwtVerify } from 'jose';
import request from 'supertest';
import { v7 as uuidv7 } from 'uuid';
import { inject } from 'vitest';
import { NEIGHBORS, PILOT_ZONE } from '../../scripts/seed-data.js';
import { createTestApp } from '../support/app.js';

/**
 * Full walk through the Phase 0 reference flow against real Postgres:
 * session → publish (idempotent) → two neighbors take the same favor → sync credentials.
 */
describe('API v1 (de punta a punta)', () => {
  let app: INestApplication;
  const tokens: Record<string, string> = {};

  const server = () => app.getHttpServer();
  const withToken = (neighbor: keyof typeof NEIGHBORS) => ({
    authorization: `Bearer ${tokens[neighbor]}`,
  });

  beforeAll(async () => {
    ({ app } = await createTestApp(inject('databaseUrl')));
    for (const neighbor of ['ana', 'beto', 'carla', 'dario', 'elena'] as const) {
      const response = await request(server())
        .post('/v1/dev/sesiones')
        .send({ telefono: NEIGHBORS[neighbor].phone })
        .expect(201);
      tokens[neighbor] = response.body.tokenDeAcceso;
    }
  });

  afterAll(async () => {
    await app?.close();
  });

  it('salud y JWKS son públicos', async () => {
    await request(server())
      .get('/v1/salud')
      .expect(200, /"baseDeDatos":"ok"/);
    const jwks = await request(server()).get('/.well-known/jwks.json').expect(200);
    expect(jwks.body.keys[0]).toMatchObject({ kty: 'EC', alg: 'ES256' });
  });

  it('todo lo demás exige token y responde en formato Problem Details', async () => {
    const response = await request(server()).post('/v1/publicaciones').send({}).expect(401);
    expect(response.headers['content-type']).toContain('application/problem+json');
    expect(response.body).toMatchObject({ status: 401, codigo: 'no_autenticado' });
    await request(server()).get('/v1/no-existe').set(withToken('ana')).expect(404);
  });

  it('publicar: 201, el reintento con la misma clave devuelve 200 y no duplica', async () => {
    const id = uuidv7();
    const body = {
      id,
      tipo: 'presto',
      categoria: 'Herramientas',
      titulo: 'Presto taladro por la tarde',
      ubicacion: { lat: -12.085_678, lng: -77.034_567 },
    };
    const first = await request(server())
      .post('/v1/publicaciones')
      .set(withToken('ana'))
      .set('Idempotency-Key', id)
      .send(body)
      .expect(201);
    expect(first.body).toMatchObject({
      id,
      autorId: NEIGHBORS.ana.id,
      zonaId: PILOT_ZONE.id,
      estado: 'abierta',
      version: 1,
      categoria: 'herramientas',
      ubicacion: { lat: -12.086, lng: -77.035 },
    });

    const retry = await request(server())
      .post('/v1/publicaciones')
      .set(withToken('ana'))
      .set('Idempotency-Key', id)
      .send(body)
      .expect(200);
    expect(retry.headers['idempotent-replayed']).toBe('true');
    expect(retry.body).toEqual(first.body);

    // Even with another idempotency key, the id generated on the phone prevents the duplicate.
    await request(server())
      .post('/v1/publicaciones')
      .set(withToken('ana'))
      .set('Idempotency-Key', uuidv7())
      .send(body)
      .expect(200);
  });

  it('valida el cuerpo y el nivel de confianza', async () => {
    const invalid = await request(server())
      .post('/v1/publicaciones')
      .set(withToken('ana'))
      .set('Idempotency-Key', uuidv7())
      .send({ id: 'no-es-uuid', tipo: 'regalo', categoria: 'x', titulo: 'ab' })
      .expect(400);
    expect(invalid.body.errores.map((error: { campo: string }) => error.campo)).toEqual(
      expect.arrayContaining(['id', 'tipo', 'categoria', 'titulo']),
    );

    const lowTrust = await request(server())
      .post('/v1/publicaciones')
      .set(withToken('dario'))
      .set('Idempotency-Key', uuidv7())
      .send({ id: uuidv7(), tipo: 'necesito', categoria: 'agua', titulo: 'Necesito agua' })
      .expect(403);
    expect(lowTrust.body.codigo).toBe('nivel_de_confianza_insuficiente');
  });

  it('dos vecinos toman el mismo favor: el primero gana, el segundo entiende por qué', async () => {
    const id = uuidv7();
    await request(server())
      .post('/v1/publicaciones')
      .set(withToken('ana'))
      .set('Idempotency-Key', id)
      .send({ id, tipo: 'necesito', categoria: 'agua', titulo: 'Necesito dos bidones de agua' })
      .expect(201);

    const takeAs = (neighbor: keyof typeof NEIGHBORS, key = uuidv7()) =>
      request(server())
        .post(`/v1/publicaciones/${id}/tomar`)
        .set(withToken(neighbor))
        .set('Idempotency-Key', key)
        .send({ versionVista: 1 });

    const betoKey = uuidv7();
    const beto = await takeAs('beto', betoKey).expect(200);
    expect(beto.body).toMatchObject({
      estado: 'en_curso',
      tomadaPorId: NEIGHBORS.beto.id,
      version: 2,
    });

    const carla = await takeAs('carla').expect(409);
    expect(carla.body).toMatchObject({ codigo: 'favor_no_disponible', estadoActual: 'en_curso' });

    // Beto's retry (his phone never got the response) does not fail.
    const retry = await takeAs('beto', betoKey).expect(200);
    expect(retry.body.version).toBe(2);

    await takeAs('ana').expect(403);
    const otherZone = await takeAs('elena').expect(403);
    expect(otherZone.body.codigo).toBe('fuera_de_tu_zona');
  });

  it('entrega credenciales para PowerSync con la audiencia y los claims que usan los Sync Streams', async () => {
    const response = await request(server())
      .get('/v1/sync/credenciales')
      .set(withToken('beto'))
      .expect(200);
    expect(response.body.endpoint).toBe('http://localhost:8080');
    const jwks = (await request(server()).get('/.well-known/jwks.json')).body;
    const { payload } = await jwtVerify(response.body.token, createLocalJWKSet(jwks), {
      audience: 'powersync',
      issuer: 'vecinal-api',
    });
    expect(payload).toMatchObject({ sub: NEIGHBORS.beto.id, zona: PILOT_ZONE.id });
  });
});

describe('API v1 con la sesión de desarrollo apagada', () => {
  it('la ruta de sesión de desarrollo no existe', async () => {
    const { app } = await createTestApp(inject('databaseUrl'), { ENABLE_DEV_SESSION: 'false' });
    try {
      await request(app.getHttpServer())
        .post('/v1/dev/sesiones')
        .send({ telefono: NEIGHBORS.ana.phone })
        .expect(404);
    } finally {
      await app.close();
    }
  });
});
