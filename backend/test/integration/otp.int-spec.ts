import type { INestApplication } from '@nestjs/common';
import { type Kysely, sql } from 'kysely';
import request from 'supertest';
import { inject } from 'vitest';
import { NEIGHBORS } from '../../scripts/seed-data.js';
import { OTP_PROVIDER } from '../../src/modules/identidad/application/ports.js';
import { FakeOtpProvider } from '../../src/modules/identidad/infrastructure/fake-otp.provider.js';
import { createKysely } from '../../src/shared/db/connection.js';
import { createTestApp } from '../support/app.js';

describe('Autenticación OTP', () => {
  let app: INestApplication;
  let provider: FakeOtpProvider;
  let db: Kysely<unknown>;

  const server = () => app.getHttpServer();
  const requestCode = (phone: string, channel: 'sms' | 'whatsapp' = 'sms') =>
    request(server()).post('/v1/auth/otp').send({ telefono: phone, canal: channel });
  const verifyCode = (phone: string, code: string) =>
    request(server()).post('/v1/auth/otp/verificar').send({ telefono: phone, codigo: code });

  beforeAll(async () => {
    ({ app } = await createTestApp(inject('databaseUrl'), {
      OTP_MAX_REQUESTS_PER_IP: '1000',
    }));
    provider = app.get(OTP_PROVIDER) as FakeOtpProvider;
    db = createKysely(inject('databaseUrl'), 2);
  });

  afterAll(async () => {
    await app?.close();
    await db?.destroy();
  });

  it('responde exactamente igual para un teléfono nuevo y uno existente', async () => {
    const existing = await requestCode(NEIGHBORS.ana.phone).expect(202);
    const created = await requestCode('+51911000001', 'whatsapp').expect(202);

    expect(created.body).toEqual(existing.body);
    expect(created.body).toEqual({ reintentarEnSegundos: 60, expiraEnSegundos: 300 });
    expect(provider.lastCodeFor(NEIGHBORS.ana.phone)).toMatch(/^[0-9]{6}$/);
    expect(provider.lastCodeFor('+51911000001')).toMatch(/^[0-9]{6}$/);
  });

  it('verifica un vecino nuevo, lo crea una sola vez con nivel 0 y no inventa refresh tokens', async () => {
    const phone = '+51911000002';
    await requestCode(phone).expect(202);
    const response = await verifyCode(phone, provider.lastCodeFor(phone)!).expect(200);

    expect(response.body.usuario).toMatchObject({ zonaId: null, nivel: 0, roles: [] });
    expect(response.body).not.toHaveProperty('refreshToken');
    const { rows } = await sql<{ nivel: number; nombre: string }>`
      SELECT nivel_confianza::int AS nivel, nombre_visible AS nombre
      FROM identidad.usuarios WHERE telefono = ${phone}
    `.execute(db);
    expect(rows).toEqual([{ nivel: 0, nombre: 'Vecino nuevo' }]);
  });

  it('reutiliza la cuenta existente sin duplicarla', async () => {
    const phone = NEIGHBORS.carla.phone;
    await requestCode(phone).expect(202);
    const response = await verifyCode(phone, provider.lastCodeFor(phone)!).expect(200);

    expect(response.body.usuario).toMatchObject({ id: NEIGHBORS.carla.id, nivel: 3 });
    const { rows } = await sql<{ count: number }>`
      SELECT count(*)::int AS count FROM identidad.usuarios WHERE telefono = ${phone}
    `.execute(db);
    expect(rows[0]?.count).toBe(1);
  });

  it('rechaza un código vencido sin revelar si existió', async () => {
    const phone = '+51911000003';
    await requestCode(phone).expect(202);
    await sql`
      UPDATE identidad.codigos_otp SET expira_en = now() - interval '1 second'
      WHERE telefono = ${phone}
    `.execute(db);

    const response = await verifyCode(phone, provider.lastCodeFor(phone)!).expect(401);
    expect(response.body.codigo).toBe('codigo_invalido');
  });

  it('rechaza la reutilización del código', async () => {
    const phone = '+51911000004';
    await requestCode(phone).expect(202);
    const code = provider.lastCodeFor(phone)!;
    await verifyCode(phone, code).expect(200);

    const response = await verifyCode(phone, code).expect(401);
    expect(response.body.codigo).toBe('codigo_invalido');
  });

  it('permite consumir el código una sola vez ante dos verificaciones concurrentes', async () => {
    const phone = '+51911000005';
    await requestCode(phone).expect(202);
    const code = provider.lastCodeFor(phone)!;

    const responses = await Promise.all([verifyCode(phone, code), verifyCode(phone, code)]);
    expect(
      responses.map((response) => response.status).sort((left, right) => left - right),
    ).toEqual([200, 401]);
    const { rows } = await sql<{ count: number }>`
      SELECT count(*)::int AS count FROM identidad.usuarios WHERE telefono = ${phone}
    `.execute(db);
    expect(rows[0]?.count).toBe(1);
  });

  it('persiste cinco intentos incorrectos y después bloquea con Retry-After', async () => {
    const phone = '+51911000006';
    await requestCode(phone).expect(202);
    const code = provider.lastCodeFor(phone)!;
    const wrongCode = code === '000000' ? '000001' : '000000';

    for (let attempt = 1; attempt <= 5; attempt += 1) {
      const response = await verifyCode(phone, wrongCode).expect(401);
      expect(response.body.codigo).toBe('codigo_invalido');
      const { rows } = await sql<{ attempts: number }>`
        SELECT intentos::int AS attempts FROM identidad.codigos_otp WHERE telefono = ${phone}
      `.execute(db);
      expect(rows[0]?.attempts).toBe(attempt);
    }

    const locked = await verifyCode(phone, code).expect(429);
    expect(locked.body).toMatchObject({
      codigo: 'demasiados_intentos',
      reintentarEnSegundos: expect.any(Number),
    });
    expect(Number(locked.headers['retry-after'])).toBeGreaterThan(0);
    expect(Number(locked.headers['retry-after'])).toBe(locked.body.reintentarEnSegundos);
  });

  it('la cuarta solicitud del mismo teléfono en 15 minutos recibe 429', async () => {
    const phone = '+51911000007';
    for (let index = 0; index < 3; index += 1) {
      await requestCode(phone).expect(202);
    }

    const limited = await requestCode(phone).expect(429);
    expect(limited.body.codigo).toBe('demasiados_intentos');
    expect(Number(limited.headers['retry-after'])).toBeGreaterThan(0);
    expect(Number(limited.headers['retry-after'])).toBe(limited.body.reintentarEnSegundos);
  });

  it('mantiene el límite por teléfono ante solicitudes concurrentes', async () => {
    const phone = '+51911000008';

    const responses = await Promise.all(Array.from({ length: 8 }, () => requestCode(phone)));
    expect(responses.filter((response) => response.status === 202)).toHaveLength(3);
    expect(responses.filter((response) => response.status === 429)).toHaveLength(5);
    for (const response of responses.filter((item) => item.status === 429)) {
      expect(Number(response.headers['retry-after'])).toBeGreaterThan(0);
    }
  });

  it('mantiene el límite por IP ante teléfonos distintos y solicitudes concurrentes', async () => {
    const { app: ipApp } = await createTestApp(inject('databaseUrl'), {
      TRUST_PROXY_HOPS: '1',
      OTP_MAX_REQUESTS_PER_IP: '2',
    });
    try {
      const responses = await Promise.all(
        Array.from({ length: 6 }, (_, index) =>
          request(ipApp.getHttpServer())
            .post('/v1/auth/otp')
            .set('X-Forwarded-For', '203.0.113.50')
            .send({ telefono: `+5191100010${index}` }),
        ),
      );
      expect(responses.filter((response) => response.status === 202)).toHaveLength(2);
      expect(responses.filter((response) => response.status === 429)).toHaveLength(4);
    } finally {
      await ipApp.close();
    }
  });

  it('convierte un fallo del proveedor real en 503 con HTTP simulado', async () => {
    const fetchMock = vi.fn(
      async (..._args: Parameters<typeof fetch>) =>
        new Response('proveedor no disponible', { status: 500 }),
    );
    vi.stubGlobal('fetch', fetchMock);
    let providerApp: INestApplication | undefined;
    try {
      ({ app: providerApp } = await createTestApp(inject('databaseUrl'), {
        OTP_PROVIDER: 'twilio',
        TWILIO_ACCOUNT_SID: 'AC_prueba',
        TWILIO_AUTH_TOKEN: 'token_de_prueba',
        TWILIO_FROM_SMS: '+15005550006',
        TWILIO_FROM_WHATSAPP: '+15005550007',
      }));
      const response = await request(providerApp.getHttpServer())
        .post('/v1/auth/otp')
        .send({ telefono: '+51911000009' })
        .expect(503);

      expect(response.body.codigo).toBe('servicio_no_disponible');
      expect(fetchMock).toHaveBeenCalledTimes(1);
    } finally {
      await providerApp?.close();
      vi.unstubAllGlobals();
    }
  });

  it('valida el cuerpo sin llamar al proveedor', async () => {
    const sentBefore = provider.sent.length;
    const response = await request(server())
      .post('/v1/auth/otp')
      .send({ telefono: '123' })
      .expect(400);

    expect(response.body.codigo).toBe('validacion');
    expect(provider.sent).toHaveLength(sentBefore);
  });
});
