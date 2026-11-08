import { TokenService } from '../../../shared/auth/token.service.js';
import type { TransactionContext, UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { AuthenticationFailure } from '../../../shared/domain/errors.js';
import { newId } from '../../../shared/domain/ids.js';
import { testConfig } from '../../../../test/support/config.js';
import { InMemorySessionRepository } from '../infrastructure/session.repository.memory.js';
import { CreateSession } from './create-session.js';
import type { PhoneTokenVerifier, RegisteredUser, UserRepository, VerifiedPhone } from './ports.js';
import { SignInWithFirebase } from './sign-in-with-firebase.js';

const transaction = {} as TransactionContext;
const unitOfWork: UnitOfWork = { run: (work) => work(transaction) };
const phone = '+51910000031';

describe('SignInWithFirebase', () => {
  let now: Date;
  let verified: VerifiedPhone | null;
  let tokens: TokenService;
  let signIn: SignInWithFirebase;
  const storedUsers = new Map<string, RegisteredUser>();

  beforeEach(() => {
    now = new Date('2026-11-07T15:00:00Z');
    verified = { phone, verifiedAt: new Date(now.getTime() - 30_000) };
    storedUsers.clear();
    const clock = { now: () => now };
    const config = testConfig();
    const users: UserRepository = {
      findByPhone: async (value) => storedUsers.get(value) ?? null,
      findById: async (id) => [...storedUsers.values()].find((user) => user.id === id) ?? null,
      findOrCreateByPhone: async (_transaction, value) => {
        const existing = storedUsers.get(value);
        if (existing) return existing;
        const user: RegisteredUser = {
          id: newId(),
          phone: value,
          displayName: 'Vecino nuevo',
          zoneId: null,
          trustLevel: 0,
          roles: [],
        };
        storedUsers.set(value, user);
        return user;
      },
    };
    const verifier: PhoneTokenVerifier = { verify: async () => verified };
    tokens = new TokenService(config, clock);
    const createSession = new CreateSession(
      new InMemorySessionRepository(),
      tokens,
      config,
      clock,
      users,
    );
    signIn = new SignInWithFirebase(unitOfWork, users, verifier, createSession, clock);
  });

  it('abre la sesión de siempre para el teléfono que confirmó Firebase', async () => {
    const session = await signIn.execute({ token: 'token-de-firebase', device: 'redmi' });

    expect(session.user).toMatchObject({ phone, trustLevel: 0, zoneId: null });
    expect(session.refreshToken).toMatch(/^[A-Za-z0-9_-]{43}$/);
    await expect(tokens.verifyAccess(session.accessToken)).resolves.toMatchObject({
      id: session.user.id,
    });
  });

  it('reutiliza al vecino que ya existía', async () => {
    const first = await signIn.execute({ token: 'uno' });
    const second = await signIn.execute({ token: 'dos' });

    expect(second.user.id).toBe(first.user.id);
    expect(storedUsers.size).toBe(1);
  });

  it('rechaza un token inválido sin crear al vecino', async () => {
    verified = null;

    const error = await signIn.execute({ token: 'malo' }).catch((reason: unknown) => reason);

    expect(error).toBeInstanceOf(AuthenticationFailure);
    expect(error).toMatchObject({ code: 'token_firebase_invalido' });
    expect(storedUsers.size).toBe(0);
  });

  it('rechaza un token de hace más de 10 minutos', async () => {
    verified = { phone, verifiedAt: new Date(now.getTime() - 10 * 60_000 - 1) };

    await expect(signIn.execute({ token: 'viejo' })).rejects.toMatchObject({
      code: 'token_firebase_invalido',
    });
  });
});
