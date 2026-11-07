import type { AppConfig } from '../../../shared/config/app-config.js';
import { TokenService } from '../../../shared/auth/token.service.js';
import type { TransactionContext, UnitOfWork } from '../../../shared/db/unit-of-work.js';
import type { Clock } from '../../../shared/domain/clock.js';
import { AuthenticationFailure, RateLimitExceeded } from '../../../shared/domain/errors.js';
import { newId } from '../../../shared/domain/ids.js';
import { testConfig } from '../../../../test/support/config.js';
import { FakeOtpProvider } from '../infrastructure/fake-otp.provider.js';
import { InMemoryOtpCodeRepository } from '../infrastructure/otp-code.repository.memory.js';
import { InMemorySessionRepository } from '../infrastructure/session.repository.memory.js';
import { CreateSession } from './create-session.js';
import type { RegisteredUser, UserRepository } from './ports.js';
import { RequestOtp } from './request-otp.js';
import { VerifyOtp, type VerifyOtpCommand } from './verify-otp.js';

const transaction = {} as TransactionContext;
const unitOfWork: UnitOfWork = { run: (work) => work(transaction) };

describe('VerifyOtp', () => {
  const phone = '+51910000011';
  let now: Date;
  let clock: Clock;
  let config: AppConfig;
  let codes: InMemoryOtpCodeRepository;
  let provider: FakeOtpProvider;
  let users: UserRepository;
  let tokens: TokenService;
  let verifyOtp: VerifyOtp;
  let storedUsers: Map<string, RegisteredUser>;

  function verifyCode(command: Omit<VerifyOtpCommand, 'ip'>) {
    return verifyOtp.execute({ ...command, ip: '192.0.2.10' });
  }

  beforeEach(async () => {
    now = new Date('2026-11-07T15:00:00Z');
    clock = { now: () => now };
    config = testConfig();
    codes = new InMemoryOtpCodeRepository();
    provider = new FakeOtpProvider(config);
    storedUsers = new Map();
    users = {
      findByPhone: async (value) => storedUsers.get(value) ?? null,
      findById: async (id) => [...storedUsers.values()].find((user) => user.id === id) ?? null,
      findOrCreateByPhone: vi.fn(
        async (_transaction: TransactionContext, value: string): Promise<RegisteredUser> => {
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
      ),
      assignZone: async () => null,
    };
    tokens = new TokenService(config, clock);
    const createSession = new CreateSession(new InMemorySessionRepository(), tokens, config, clock);
    verifyOtp = new VerifyOtp(unitOfWork, codes, users, createSession, config, clock);
    const requestOtp = new RequestOtp(unitOfWork, codes, provider, config, clock);
    await requestOtp.execute({ phone, channel: 'sms', ip: '192.0.2.10' });
  });

  it('acepta el código correcto, registra nivel 0 y emite acceso con refresh', async () => {
    const result = await verifyCode({
      phone,
      code: provider.lastCodeFor(phone)!,
      device: 'prueba',
    });

    expect(result.user).toMatchObject({ phone, trustLevel: 0, zoneId: null });
    expect(result.refreshToken).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(result.refreshExpiresAt.toISOString()).toBe('2026-12-07T15:00:00.000Z');
    await expect(tokens.verifyAccess(result.accessToken)).resolves.toMatchObject({
      id: result.user.id,
      trustLevel: 0,
      zoneId: null,
      sessionId: expect.any(String),
    });
  });

  it('rechaza un código vencido con el mismo codigo_invalido', async () => {
    now = new Date(now.getTime() + 5 * 60_000 + 1);

    await expect(verifyCode({ phone, code: provider.lastCodeFor(phone)! })).rejects.toMatchObject({
      code: 'codigo_invalido',
    });
    expect(storedUsers.size).toBe(0);
  });

  it('rechaza la reutilización y no crea otra sesión', async () => {
    const code = provider.lastCodeFor(phone)!;
    await verifyCode({ phone, code });

    await expect(verifyCode({ phone, code })).rejects.toMatchObject({
      code: 'codigo_invalido',
    });
    expect(storedUsers.size).toBe(1);
  });

  it('persiste cada intento fallido y bloquea después del máximo', async () => {
    const wrongCode = provider.lastCodeFor(phone) === '000000' ? '000001' : '000000';
    for (let attempt = 1; attempt <= 5; attempt += 1) {
      const error = await verifyOtp
        .execute({ phone, code: wrongCode, ip: '192.0.2.10' })
        .catch((reason: unknown) => reason);
      expect(error).toBeInstanceOf(AuthenticationFailure);
      const record = await codes.findLatestActiveForUpdate(transaction, phone, now);
      expect(record?.attempts).toBe(attempt);
    }

    const locked = await verifyOtp
      .execute({ phone, code: provider.lastCodeFor(phone)!, ip: '192.0.2.10' })
      .catch((reason: unknown) => reason);
    expect(locked).toBeInstanceOf(RateLimitExceeded);
    expect(locked).toMatchObject({ retryAfterSeconds: 15 * 60 });
    const record = await codes.findLatestActiveForUpdate(transaction, phone, now);
    expect(record?.attempts).toBe(5);
  });
});
