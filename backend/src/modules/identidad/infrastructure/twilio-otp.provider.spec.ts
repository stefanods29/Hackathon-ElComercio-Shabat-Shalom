import { ServiceUnavailableException } from '@nestjs/common';
import { testConfig } from '../../../../test/support/config.js';
import { TwilioOtpProvider } from './twilio-otp.provider.js';

const twilioConfig = () =>
  testConfig({
    OTP_PROVIDER: 'twilio',
    TWILIO_ACCOUNT_SID: 'AC_prueba',
    TWILIO_AUTH_TOKEN: 'token_de_prueba',
    TWILIO_FROM_SMS: '+15005550006',
    TWILIO_FROM_WHATSAPP: '+15005550007',
  });

describe('TwilioOtpProvider', () => {
  it.each([
    { channel: 'sms' as const, from: '+15005550006', prefix: '' },
    { channel: 'whatsapp' as const, from: '+15005550007', prefix: 'whatsapp:' },
  ])('envía la solicitud $channel con HTTP simulado', async ({ channel, from, prefix }) => {
    const fetchMock = vi.fn(
      async (..._args: Parameters<typeof fetch>) => new Response('{}', { status: 201 }),
    );
    const provider = new TwilioOtpProvider(twilioConfig(), fetchMock);

    await provider.send('+51910000020', '123456', channel);

    const [url, init] = fetchMock.mock.calls[0]!;
    expect(url).toBe('https://api.twilio.com/2010-04-01/Accounts/AC_prueba/Messages.json');
    expect(init?.method).toBe('POST');
    expect(new Headers(init?.headers).get('authorization')).toBe(
      `Basic ${Buffer.from('AC_prueba:token_de_prueba').toString('base64')}`,
    );
    const body = init?.body as URLSearchParams;
    expect(body.get('To')).toBe(`${prefix}+51910000020`);
    expect(body.get('From')).toBe(`${prefix}${from}`);
    expect(body.get('Body')).toBe(
      'Tu código de Vecinal es 123456. Vence en 5 minutos. No lo compartas.',
    );
  });

  it('convierte un rechazo HTTP del proveedor en 503 sin registrar el código', async () => {
    const fetchMock = vi.fn(async () => new Response('error interno', { status: 500 }));
    const provider = new TwilioOtpProvider(twilioConfig(), fetchMock);

    await expect(provider.send('+51910000021', '654321', 'sms')).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('convierte un error de red en 503', async () => {
    const fetchMock = vi.fn(async () => {
      throw new Error('red no disponible');
    });
    const provider = new TwilioOtpProvider(twilioConfig(), fetchMock);

    await expect(provider.send('+51910000022', '654321', 'sms')).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });
});
