import { createHmac } from 'node:crypto';
import type { AppConfig } from '../../../shared/config/app-config.js';
import type { TransactionContext, UnitOfWork } from '../../../shared/db/unit-of-work.js';
import type { Clock } from '../../../shared/domain/clock.js';
import { RateLimitExceeded } from '../../../shared/domain/errors.js';
import { testConfig } from '../../../../test/support/config.js';
import { FakeOtpProvider } from '../infrastructure/fake-otp.provider.js';
import { InMemoryOtpCodeRepository } from '../infrastructure/otp-code.repository.memory.js';
import type { OtpProvider } from './ports.js';
import { RequestOtp } from './request-otp.js';

const transaction = {} as TransactionContext;
const unitOfWork: UnitOfWork = { run: (work) => work(transaction) };

describe('RequestOtp', () => {
  let now: Date;
  let clock: Clock;
  let config: AppConfig;
  let codes: InMemoryOtpCodeRepository;
  let provider: FakeOtpProvider;
  let requestOtp: RequestOtp;

  beforeEach(() => {
    now = new Date('2026-11-07T15:00:00Z');
    clock = { now: () => now };
    config = testConfig();
    codes = new InMemoryOtpCodeRepository();
    provider = new FakeOtpProvider(config);
    requestOtp = new RequestOtp(unitOfWork, codes, provider, config, clock);
  });

  it('genera seis dígitos, guarda solo su HMAC y devuelve la vigencia', async () => {
    const result = await requestOtp.execute({
      phone: '+51910000001',
      channel: 'sms',
      ip: '192.0.2.1',
    });
    const code = provider.lastCodeFor('+51910000001');
    const record = await codes.findLatestActiveForUpdate(transaction, '+51910000001', now);

    expect(result).toEqual({ retryAfterSeconds: 60, expiresInSeconds: 300 });
    expect(code).toMatch(/^[0-9]{6}$/);
    expect(record?.codeHash).toBe(
      createHmac('sha256', config.OTP_HASH_SECRET).update(`+51910000001:${code}`).digest('hex'),
    );
    expect(record?.codeHash).not.toContain(code);
  });

  it('limita por teléfono e indica cuándo sale la solicitud más antigua de la ventana', async () => {
    config = testConfig({ OTP_MAX_REQUESTS_PER_PHONE: '2' });
    requestOtp = new RequestOtp(unitOfWork, codes, provider, config, clock);
    const command = { phone: '+51910000002', channel: 'sms' as const, ip: '192.0.2.2' };
    await requestOtp.execute(command);
    await requestOtp.execute(command);

    const error = await requestOtp.execute(command).catch((reason: unknown) => reason);
    expect(error).toBeInstanceOf(RateLimitExceeded);
    expect(error).toMatchObject({ retryAfterSeconds: 15 * 60 });
    expect(provider.sent).toHaveLength(2);
  });

  it('limita por IP aunque cada solicitud use un teléfono distinto', async () => {
    config = testConfig({ OTP_MAX_REQUESTS_PER_IP: '2' });
    requestOtp = new RequestOtp(unitOfWork, codes, provider, config, clock);
    const execute = (suffix: number) =>
      requestOtp.execute({
        phone: `+5191000010${suffix}`,
        channel: 'whatsapp',
        ip: '192.0.2.3',
      });
    await execute(1);
    await execute(2);

    const error = await execute(3).catch((reason: unknown) => reason);
    expect(error).toBeInstanceOf(RateLimitExceeded);
    expect(error).toMatchObject({ retryAfterSeconds: 60 * 60 });
    expect(provider.sent).toHaveLength(2);
  });

  it('conserva la solicitud contabilizada si el proveedor falla después del commit', async () => {
    const failingProvider: OtpProvider = { send: vi.fn().mockRejectedValue(new Error('caído')) };
    requestOtp = new RequestOtp(unitOfWork, codes, failingProvider, config, clock);

    await expect(
      requestOtp.execute({ phone: '+51910000003', channel: 'sms', ip: '192.0.2.4' }),
    ).rejects.toThrow('caído');
    await expect(codes.countByPhoneSince('+51910000003', new Date(0))).resolves.toMatchObject({
      count: 1,
    });
  });
});
