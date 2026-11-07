import { BusinessRuleViolation } from '../../../shared/domain/errors.js';
import type { OtpProvider } from '../application/ports.js';

/** With OTP_PROVIDER=firebase the API never sends codes: Firebase does it from the app. */
export class DisabledOtpProvider implements OtpProvider {
  send(): Promise<void> {
    return Promise.reject(
      new BusinessRuleViolation(
        'metodo_no_disponible',
        'Este servidor verifica el teléfono con Firebase desde la app.',
        'conflict',
      ),
    );
  }
}
