import { ServiceUnavailableException } from '@nestjs/common';
import type { DecodedIdToken } from 'firebase-admin/auth';
import { BusinessRuleViolation } from '../../../shared/domain/errors.js';
import {
  DisabledPhoneTokenVerifier,
  FirebasePhoneTokenVerifier,
} from './firebase-phone-token.verifier.js';

const authTime = 1_794_000_000;

function decoded(overrides: Record<string, unknown> = {}): DecodedIdToken {
  return {
    aud: 'vecinal-prueba',
    auth_time: authTime,
    exp: authTime + 3600,
    iat: authTime,
    iss: 'https://securetoken.google.com/vecinal-prueba',
    sub: 'uid-1',
    uid: 'uid-1',
    phone_number: '+51910000041',
    firebase: { identities: {}, sign_in_provider: 'phone' },
    ...overrides,
  } as DecodedIdToken;
}

function failingWith(code: string) {
  return async (): Promise<DecodedIdToken> => {
    throw Object.assign(new Error(code), { code });
  };
}

describe('FirebasePhoneTokenVerifier', () => {
  it('devuelve el teléfono y el momento en que Firebase lo confirmó', async () => {
    const verifier = new FirebasePhoneTokenVerifier('vecinal-prueba', async () => decoded());

    await expect(verifier.verify('token')).resolves.toEqual({
      phone: '+51910000041',
      verifiedAt: new Date(authTime * 1000),
    });
  });

  it('rechaza un ingreso que no fue por teléfono', async () => {
    const verifier = new FirebasePhoneTokenVerifier('vecinal-prueba', async () =>
      decoded({ firebase: { identities: {}, sign_in_provider: 'google.com' } }),
    );

    await expect(verifier.verify('token')).resolves.toBeNull();
  });

  it('rechaza un token sin teléfono o con un formato que no es internacional', async () => {
    for (const phone of [undefined, '987654321']) {
      const verifier = new FirebasePhoneTokenVerifier('vecinal-prueba', async () =>
        decoded({ phone_number: phone }),
      );
      await expect(verifier.verify('token')).resolves.toBeNull();
    }
  });

  it('trata un token vencido o de otro proyecto como inválido', async () => {
    for (const code of ['auth/id-token-expired', 'auth/argument-error']) {
      const verifier = new FirebasePhoneTokenVerifier('vecinal-prueba', failingWith(code));
      await expect(verifier.verify('token')).resolves.toBeNull();
    }
  });

  it('responde 503 si no puede consultar las claves de Google', async () => {
    for (const code of ['auth/internal-error', 'ECONNRESET']) {
      const verifier = new FirebasePhoneTokenVerifier('vecinal-prueba', failingWith(code));
      await expect(verifier.verify('token')).rejects.toBeInstanceOf(ServiceUnavailableException);
    }
  });
});

describe('DisabledPhoneTokenVerifier', () => {
  it('responde metodo_no_disponible si el servidor no tiene Firebase', async () => {
    const error = await new DisabledPhoneTokenVerifier()
      .verify()
      .catch((reason: unknown) => reason);

    expect(error).toBeInstanceOf(BusinessRuleViolation);
    expect(error).toMatchObject({ code: 'metodo_no_disponible', kind: 'conflict' });
  });
});
