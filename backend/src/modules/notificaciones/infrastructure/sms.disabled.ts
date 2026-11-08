import type { SmsProvider, SmsResult } from '../application/ports.js';

/**
 * `SMS_PROVIDER=none`: the SMS backup is switched off on purpose (production until decision 13.3.4
 * picks a provider). Reviews record `sin_respaldo` / `sin_proveedor` instead of pretending.
 */
export class DisabledSmsProvider implements SmsProvider {
  readonly name = 'none' as const;

  async send(): Promise<SmsResult> {
    return { status: 'failed', retryable: false };
  }
}
