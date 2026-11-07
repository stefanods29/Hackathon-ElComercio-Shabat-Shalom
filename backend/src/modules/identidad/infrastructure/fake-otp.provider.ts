import { Logger } from '@nestjs/common';
import type { AppConfig } from '../../../shared/config/app-config.js';
import type { OtpChannel, OtpProvider } from '../application/ports.js';

export interface SentOtp {
  readonly phone: string;
  readonly code: string;
  readonly channel: OtpChannel;
}

export class FakeOtpProvider implements OtpProvider {
  readonly sent: SentOtp[] = [];

  constructor(
    private readonly config: AppConfig,
    private readonly logger: Pick<Logger, 'log'> = new Logger('FakeOtpProvider'),
  ) {}

  async send(phone: string, code: string, channel: OtpChannel): Promise<void> {
    this.sent.push({ phone, code, channel });
    if (this.config.NODE_ENV === 'development') {
      this.logger.log(`Código OTP para ${phone} por ${channel}: ${code}`);
    }
  }

  lastCodeFor(phone: string): string | undefined {
    return this.sent.findLast((message) => message.phone === phone)?.code;
  }
}
