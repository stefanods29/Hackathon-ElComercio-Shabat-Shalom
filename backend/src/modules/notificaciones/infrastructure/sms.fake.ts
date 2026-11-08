import { ConsoleLogger } from '@nestjs/common';
import type { SmsProvider, SmsResult } from '../application/ports.js';

/**
 * Local SMS adapter: nothing leaves the machine. It keeps the last two digits of each phone and
 * the text, so a developer can see that the backup fired without exposing the number.
 */
export class FakeSmsProvider implements SmsProvider {
  readonly name = 'fake' as const;
  readonly sent: { readonly phoneSuffix: string; readonly text: string }[] = [];
  private readonly logger = new ConsoleLogger('FakeSmsProvider', { json: true });

  constructor(
    private readonly costCents: number,
    private readonly logToConsole: boolean,
  ) {}

  async send(phone: string, text: string): Promise<SmsResult> {
    const phoneSuffix = phone.slice(-2);
    this.sent.push({ phoneSuffix, text });
    if (this.logToConsole) {
      this.logger.log({ evento: 'sms.falso', telefono: `…${phoneSuffix}`, texto: text });
    }
    return { status: 'sent', costCents: this.costCents };
  }
}
