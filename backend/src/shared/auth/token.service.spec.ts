import { generateKeyPairSync } from 'node:crypto';
import { createLocalJWKSet, jwtVerify } from 'jose';
import { testConfig } from '../../../test/support/config.js';
import type { Clock } from '../domain/clock.js';
import type { Actor } from './actor.js';
import { InvalidToken, POWERSYNC_AUDIENCE, TokenService } from './token.service.js';

const actor: Actor = {
  id: '01970000-0000-7000-8000-0000000000a1',
  zoneId: '01970000-0000-7000-8000-000000000001',
  trustLevel: 2,
  roles: ['coordinador'],
};

describe('TokenService', () => {
  let now = new Date('2026-11-06T15:00:00Z');
  const clock: Clock = { now: () => now };
  const tokens = new TokenService(testConfig(), clock);

  beforeEach(() => {
    now = new Date('2026-11-06T15:00:00Z');
  });

  it('emite tokens de acceso que la API verifica y que devuelven al mismo actor', async () => {
    const { token, expiresAt } = await tokens.issueAccess(actor);
    expect(expiresAt.toISOString()).toBe('2026-11-06T15:15:00.000Z');
    await expect(tokens.verifyAccess(token)).resolves.toEqual(actor);
  });

  it('el token de PowerSync se valida con el JWKS público y lleva sub y zona', async () => {
    const { token } = await tokens.issueSync(actor);
    const { payload, protectedHeader } = await jwtVerify(token, createLocalJWKSet(tokens.jwks()), {
      audience: POWERSYNC_AUDIENCE,
      currentDate: now,
    });
    expect(protectedHeader).toMatchObject({ alg: 'ES256', kid: 'dev-1' });
    expect(payload).toMatchObject({ sub: actor.id, zona: actor.zoneId, nivel: 2 });
  });

  it('un token de PowerSync no sirve para la API (audiencias separadas)', async () => {
    const { token } = await tokens.issueSync(actor);
    await expect(tokens.verifyAccess(token)).rejects.toBeInstanceOf(InvalidToken);
  });

  it('rechaza tokens vencidos', async () => {
    const { token } = await tokens.issueAccess(actor);
    now = new Date('2026-11-06T15:16:00Z');
    await expect(tokens.verifyAccess(token)).rejects.toBeInstanceOf(InvalidToken);
  });

  it('solo publica la parte pública de la clave', () => {
    const [key] = tokens.jwks().keys;
    expect(key).toMatchObject({ kty: 'EC', crv: 'P-256', alg: 'ES256', use: 'sig', kid: 'dev-1' });
    expect(key).not.toHaveProperty('d');
  });

  it('exige una clave EC P-256', () => {
    const rsa = generateKeyPairSync('rsa', { modulusLength: 2048 })
      .privateKey.export({ format: 'pem', type: 'pkcs8' })
      .toString();
    expect(() => new TokenService(testConfig({ JWT_PRIVATE_KEY_PEM: rsa }), clock)).toThrow(
      /P-256/,
    );
  });
});
