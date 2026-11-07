import type { INestApplication } from '@nestjs/common';
import type { NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { inject } from 'vitest';
import { AppModule } from '../../src/app.module.js';
import { OTP_PROVIDER } from '../../src/modules/identidad/application/ports.js';
import type { FakeOtpProvider } from '../../src/modules/identidad/infrastructure/fake-otp.provider.js';
import { APP_CONFIG } from '../../src/shared/config/app-config.js';
import { CLOCK } from '../../src/shared/domain/clock.js';
import { testConfig } from '../support/config.js';

describe('Bloqueos OTP persistentes por teléfono e IP', () => {
  let now: Date;
  let sequence = 0;
  const apps = new Set<INestApplication>();
  const phone = () => '+51998000' + String(++sequence).padStart(3, '0');

  beforeEach(() => {
    now = new Date();
  });
  afterEach(async () => {
    for (const app of apps) await app.close();
    apps.clear();
  });

  async function start(overrides: Record<string, string> = {}) {
    const config = testConfig({
      DATABASE_URL: inject('databaseUrl'),
      TRUST_PROXY_HOPS: '1',
      OTP_MAX_REQUESTS_PER_PHONE: '100',
      OTP_MAX_REQUESTS_PER_IP: '1000',
      OTP_MAX_ATTEMPTS_PER_IP: '1000',
      ...overrides,
    });
    const context = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(APP_CONFIG)
      .useValue(config)
      .overrideProvider(CLOCK)
      .useValue({ now: () => now })
      .compile();
    const app = context.createNestApplication<NestExpressApplication>({ logger: false });
    app.set('trust proxy', config.TRUST_PROXY_HOPS);
    await app.init();
    apps.add(app);
    const provider = app.get<FakeOtpProvider>(OTP_PROVIDER);
    return {
      app,
      provider,
      send: (number: string) =>
        request(app.getHttpServer())
          .post('/v1/auth/otp')
          .set('X-Forwarded-For', '198.51.100.200')
          .send({ telefono: number }),
      verify: (number: string, code: string, ip = '198.51.100.201') =>
        request(app.getHttpServer())
          .post('/v1/auth/otp/verificar')
          .set('X-Forwarded-For', ip)
          .send({ telefono: number, codigo: code }),
      wrong: (number: string) => (provider.lastCodeFor(number) === '000000' ? '000001' : '000000'),
    };
  }

  it('acumula fallos entre reenvíos y no permite solicitar ni verificar durante el bloqueo', async () => {
    const api = await start();
    const number = phone();
    await api.send(number).expect(202);
    for (let i = 0; i < 4; i++) await api.verify(number, api.wrong(number)).expect(401);
    await api.send(number).expect(202);
    await api.verify(number, api.wrong(number)).expect(401);
    const locked = await api.verify(number, api.provider.lastCodeFor(number)!).expect(429);
    expect(Number(locked.headers['retry-after'])).toBe(900);
    const sent = api.provider.sent.length;
    await api.send(number).expect(429);
    expect(api.provider.sent).toHaveLength(sent);
  });

  it('bloquea quince minutos desde el quinto fallo, aunque el OTP caduque o se reinicie la API', async () => {
    const api = await start();
    const number = phone();
    await api.send(number).expect(202);
    now = new Date(now.getTime() + 4 * 60_000);
    for (let i = 0; i < 5; i++) await api.verify(number, api.wrong(number)).expect(401);
    const locked = await api.verify(number, api.wrong(number)).expect(429);
    expect(locked.body.reintentarEnSegundos).toBe(900);
    now = new Date(now.getTime() + 6 * 60_000);
    await api.app.close();
    apps.delete(api.app);
    const restarted = await start();
    const stillLocked = await restarted.verify(number, '000000').expect(429);
    expect(Number(stillLocked.headers['retry-after'])).toBe(540);
    await restarted.send(number).expect(429);
    now = new Date(now.getTime() + 9 * 60_000);
    await restarted.send(number).expect(202);
    await restarted.verify(number, restarted.provider.lastCodeFor(number)!).expect(200);
  });

  it('cuenta por IP entre teléfonos y un acceso válido no borra los fallos de esa IP', async () => {
    const api = await start({ OTP_MAX_ATTEMPTS_PER_IP: '3' });
    const numbers = Array.from({ length: 4 }, phone);
    for (const number of numbers) await api.send(number).expect(202);
    const ip = '203.0.113.71';
    await api.verify(numbers[0]!, api.wrong(numbers[0]!), ip).expect(401);
    await api.verify(numbers[1]!, api.wrong(numbers[1]!), ip).expect(401);
    await api.verify(numbers[2]!, api.provider.lastCodeFor(numbers[2]!)!, ip).expect(200);
    await api.verify(numbers[3]!, api.wrong(numbers[3]!), ip).expect(401);
    const locked = await api
      .verify(numbers[3]!, api.provider.lastCodeFor(numbers[3]!)!, ip)
      .expect(429);
    expect(locked.body.reintentarEnSegundos).toBe(900);
    expect(locked.headers['retry-after']).toBe('900');
  });

  it('mantiene el límite por IP ante ocho verificaciones concurrentes de teléfonos distintos', async () => {
    const api = await start({ OTP_MAX_ATTEMPTS_PER_IP: '3' });
    const numbers = Array.from({ length: 8 }, phone);
    for (const number of numbers) await api.send(number).expect(202);
    const responses = await Promise.all(
      numbers.map((number) => api.verify(number, api.wrong(number), '203.0.113.72')),
    );
    expect(responses.filter((res) => res.status === 401)).toHaveLength(3);
    expect(responses.filter((res) => res.status === 429)).toHaveLength(5);
  });

  it('cuenta también los fallos sin un código vigente y recupera el acceso al vencer el bloqueo IP', async () => {
    const api = await start({ OTP_MAX_ATTEMPTS_PER_IP: '3' });
    const ip = '203.0.113.73';
    for (let i = 0; i < 3; i++) await api.verify(phone(), '000000', ip).expect(401);
    await api.verify(phone(), '000000', ip).expect(429);
    now = new Date(now.getTime() + 15 * 60_000);
    const number = phone();
    await api.send(number).expect(202);
    await api.verify(number, api.provider.lastCodeFor(number)!, ip).expect(200);
  });

  it('normaliza las representaciones equivalentes de IPv6 antes de limitar y bloquear', async () => {
    const api = await start({ OTP_MAX_ATTEMPTS_PER_IP: '3' });
    const numbers = Array.from({ length: 8 }, phone);
    for (const number of numbers) await api.send(number).expect(202);
    const ips = ['2001:db8::77', '2001:0db8:0:0:0:0:0:77', '2001:db8:0::77'];
    const responses = await Promise.all(
      numbers.map((number, index) =>
        api.verify(number, api.wrong(number), ips[index % ips.length]!),
      ),
    );
    expect(responses.filter((res) => res.status === 401)).toHaveLength(3);
    expect(responses.filter((res) => res.status === 429)).toHaveLength(5);
  });
});
