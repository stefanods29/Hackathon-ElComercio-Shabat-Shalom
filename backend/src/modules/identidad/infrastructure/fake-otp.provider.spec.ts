import { testConfig } from '../../../../test/support/config.js';
import { FakeOtpProvider } from './fake-otp.provider.js';

describe('FakeOtpProvider', () => {
  it('conserva los códigos para las pruebas y solo los registra en development', async () => {
    const developmentLogger = { log: vi.fn() };
    const development = new FakeOtpProvider(
      testConfig({ NODE_ENV: 'development' }),
      developmentLogger,
    );
    await development.send('+51910000001', '123456', 'sms');

    expect(development.lastCodeFor('+51910000001')).toBe('123456');
    expect(development.sent).toEqual([{ phone: '+51910000001', code: '123456', channel: 'sms' }]);
    expect(developmentLogger.log).toHaveBeenCalledWith(expect.stringContaining('123456'));

    const testLogger = { log: vi.fn() };
    const test = new FakeOtpProvider(testConfig(), testLogger);
    await test.send('+51910000002', '654321', 'whatsapp');
    expect(testLogger.log).not.toHaveBeenCalled();
  });
});
