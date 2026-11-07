import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { inject } from 'vitest';
import {
  PHONE_TOKEN_VERIFIER,
  type PhoneTokenVerifier,
} from '../../src/modules/identidad/application/ports.js';
import { createTestApp } from '../support/app.js';

/** Tokens the fake verifier accepts: each one stands for a phone confirmed by Firebase. */
const confirmedPhones = new Map([
  ['token-ana', '+51919900001'],
  ['token-beto', '+51919900002'],
]);

const fakeVerifier: PhoneTokenVerifier = {
  verify: async (token) => {
    const phone = confirmedPhones.get(token);
    return phone ? { phone, verifiedAt: new Date() } : null;
  },
};

describe('Ingreso con Firebase', () => {
  let app: INestApplication;
  let otpOnly: INestApplication;

  const signIn = (target: INestApplication, token: string) =>
    request(target.getHttpServer())
      .post('/v1/auth/firebase')
      .send({ tokenFirebase: token, dispositivo: 'prueba' });

  beforeAll(async () => {
    ({ app } = await createTestApp(
      inject('databaseUrl'),
      { OTP_PROVIDER: 'firebase', FIREBASE_PROJECT_ID: 'vecinal-prueba' },
      (builder) => builder.overrideProvider(PHONE_TOKEN_VERIFIER).useValue(fakeVerifier),
    ));
    ({ app: otpOnly } = await createTestApp(inject('databaseUrl')));
  });

  afterAll(async () => {
    await app?.close();
    await otpOnly?.close();
  });

  it('abre una sesión con refresh para el teléfono que confirmó Firebase', async () => {
    const response = await signIn(app, 'token-ana').expect(200);

    expect(response.body.usuario).toMatchObject({ zonaId: null, nivel: 0, roles: [] });
    expect(response.body.refreshToken).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(typeof response.body.tokenDeAcceso).toBe('string');
  });

  it('reutiliza la cuenta del mismo teléfono', async () => {
    const first = await signIn(app, 'token-beto').expect(200);
    const second = await signIn(app, 'token-beto').expect(200);

    expect(second.body.usuario.id).toBe(first.body.usuario.id);
  });

  it('rechaza un token que Firebase no confirmó', async () => {
    const response = await signIn(app, 'token-falso').expect(401);

    expect(response.body.codigo).toBe('token_firebase_invalido');
  });

  it('con OTP_PROVIDER=firebase las rutas de código responden metodo_no_disponible', async () => {
    const response = await request(app.getHttpServer())
      .post('/v1/auth/otp')
      .send({ telefono: '+51919900003', canal: 'sms' })
      .expect(409);

    expect(response.body.codigo).toBe('metodo_no_disponible');
  });

  it('sin FIREBASE_PROJECT_ID el ingreso con Firebase no está disponible', async () => {
    const response = await signIn(otpOnly, 'token-ana').expect(409);

    expect(response.body.codigo).toBe('metodo_no_disponible');
  });
});
