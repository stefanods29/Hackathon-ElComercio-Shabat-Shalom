import type { INestApplication } from '@nestjs/common';
import { sql } from 'kysely';
import request from 'supertest';
import { v7 as uuidv7 } from 'uuid';
import { inject } from 'vitest';
import { NEIGHBOR_ZONE, PILOT_ZONE } from '../../scripts/seed-data.js';
import { OTP_PROVIDER } from '../../src/modules/identidad/application/ports.js';
import { FakeOtpProvider } from '../../src/modules/identidad/infrastructure/fake-otp.provider.js';
import { TokenService } from '../../src/shared/auth/token.service.js';
import { createKysely } from '../../src/shared/db/connection.js';
import { createTestApp } from '../support/app.js';

describe('Zonas del vecino', () => {
  let app: INestApplication;
  let provider: FakeOtpProvider;
  let tokens: TokenService;
  let db: ReturnType<typeof createKysely>;

  const server = () => app.getHttpServer();
  const register = async (phone: string) => {
    await request(server()).post('/v1/auth/otp').send({ telefono: phone }).expect(202);
    const response = await request(server())
      .post('/v1/auth/otp/verificar')
      .send({ telefono: phone, codigo: provider.lastCodeFor(phone) })
      .expect(200);
    return response.body;
  };
  const choose = (token: string, zoneId: string, key = uuidv7()) =>
    request(server())
      .put('/v1/yo/zona')
      .set('authorization', `Bearer ${token}`)
      .set('Idempotency-Key', key)
      .send({ zonaId: zoneId });

  beforeAll(async () => {
    ({ app } = await createTestApp(inject('databaseUrl'), {
      OTP_MAX_REQUESTS_PER_IP: '1000',
    }));
    provider = app.get(OTP_PROVIDER) as FakeOtpProvider;
    tokens = app.get(TokenService);
    db = createKysely(inject('databaseUrl'), 2);
  });

  afterAll(async () => {
    await app?.close();
    await db?.destroy();
  });

  it('lista públicamente las zonas sin el polígono', async () => {
    const response = await request(server()).get('/v1/zonas').expect(200);

    expect(response.body).toHaveLength(2);
    expect(response.body).toEqual(
      expect.arrayContaining([
        { id: PILOT_ZONE.id, nombre: PILOT_ZONE.name, distrito: PILOT_ZONE.district },
      ]),
    );
    for (const zone of response.body) {
      expect(Object.keys(zone).sort()).toEqual(['distrito', 'id', 'nombre']);
      expect(zone).not.toHaveProperty('limite');
      expect(zone).not.toHaveProperty('poligono');
    }
  });

  it('elige la zona, acepta la misma zona y actualiza los tokens de acceso y sincronización', async () => {
    const session = await register('+51912000001');
    const key = uuidv7();
    const chosen = await choose(session.tokenDeAcceso, PILOT_ZONE.id, key).expect(200);

    expect(chosen.body.usuario.zonaId).toBe(PILOT_ZONE.id);
    await expect(tokens.verifyAccess(chosen.body.tokenDeAcceso)).resolves.toMatchObject({
      id: session.usuario.id,
      zoneId: PILOT_ZONE.id,
    });

    const replay = await choose(session.tokenDeAcceso, PILOT_ZONE.id, key).expect(200);
    expect(replay.headers['idempotent-replayed']).toBe('true');
    expect(replay.body).toEqual(chosen.body);

    const sync = await request(server())
      .get('/v1/sync/credenciales')
      .set('authorization', `Bearer ${chosen.body.tokenDeAcceso}`)
      .expect(200);
    await expect(tokens.verify(sync.body.token, 'powersync')).resolves.toMatchObject({
      id: session.usuario.id,
      zoneId: PILOT_ZONE.id,
    });

    const same = await choose(chosen.body.tokenDeAcceso, PILOT_ZONE.id).expect(200);
    expect(same.body.usuario).toEqual(chosen.body.usuario);
  });

  it('responde 404 si la zona no existe', async () => {
    const session = await register('+51912000002');

    const response = await choose(session.tokenDeAcceso, uuidv7()).expect(404);
    expect(response.body.codigo).toBe('recurso_no_encontrado');
  });

  it('solo asigna una zona cuando dos elecciones distintas compiten', async () => {
    const session = await register('+51912000003');

    const responses = await Promise.all([
      choose(session.tokenDeAcceso, PILOT_ZONE.id),
      choose(session.tokenDeAcceso, NEIGHBOR_ZONE.id),
    ]);
    expect(
      responses.map((response) => response.status).sort((left, right) => left - right),
    ).toEqual([200, 409]);
    const { rows } = await sql<{ zoneId: string }>`
      SELECT zona_id::text AS "zoneId" FROM identidad.usuarios WHERE id = ${session.usuario.id}
    `.execute(db);
    const winner = responses.find((response) => response.status === 200);
    expect(rows).toEqual([{ zoneId: winner?.body.usuario.zonaId }]);
  });
});
