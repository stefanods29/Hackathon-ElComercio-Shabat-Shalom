import { ServiceUnavailableException } from '@nestjs/common';
import type { AppConfig } from '../../../shared/config/app-config.js';
import type { OtpChannel, OtpProvider } from '../application/ports.js';

export class TwilioOtpProvider implements OtpProvider {
  constructor(
    private readonly config: AppConfig,
    private readonly fetchImpl: typeof fetch = globalThis.fetch,
  ) {}

  async send(phone: string, code: string, channel: OtpChannel): Promise<void> {
    const accountSid = this.config.TWILIO_ACCOUNT_SID!;
    const from =
      channel === 'whatsapp' ? this.config.TWILIO_FROM_WHATSAPP! : this.config.TWILIO_FROM_SMS!;
    const prefix = channel === 'whatsapp' ? 'whatsapp:' : '';
    const body = new URLSearchParams({
      To: `${prefix}${phone}`,
      From: `${prefix}${from}`,
      Body: `Tu código de Vecinal es ${code}. Vence en ${this.config.OTP_TTL_MINUTES} minutos. No lo compartas.`,
    });

    try {
      const response = await this.fetchImpl(
        `https://api.twilio.com/2010-04-01/Accounts/${encodeURIComponent(accountSid)}/Messages.json`,
        {
          method: 'POST',
          headers: {
            authorization: `Basic ${Buffer.from(`${accountSid}:${this.config.TWILIO_AUTH_TOKEN}`).toString('base64')}`,
            'content-type': 'application/x-www-form-urlencoded',
          },
          body,
        },
      );
      if (!response.ok) throw new ServiceUnavailableException();
    } catch (error) {
      if (error instanceof ServiceUnavailableException) throw error;
      throw new ServiceUnavailableException();
    }
  }
}
