import { ServiceUnavailableException } from '@nestjs/common';
import { getApps, initializeApp, type App } from 'firebase-admin/app';
import { getAuth, type DecodedIdToken } from 'firebase-admin/auth';
import { BusinessRuleViolation } from '../../../shared/domain/errors.js';
import type { PhoneTokenVerifier, VerifiedPhone } from '../application/ports.js';

const APP_NAME = 'vecinal-identidad';
const PHONE_FORMAT = /^\+[1-9][0-9]{7,14}$/;

function appFor(projectId: string): App {
  return getApps().find((app) => app.name === APP_NAME) ?? initializeApp({ projectId }, APP_NAME);
}

/** Problems with the token itself; anything else (network, Google keys) is a 503. */
function isTokenError(error: unknown): boolean {
  const code = (error as { code?: unknown } | null)?.code;
  return typeof code === 'string' && code.startsWith('auth/') && code !== 'auth/internal-error';
}

/**
 * Checks Firebase ID tokens against Google's public keys. It only needs the project ID: no
 * service account or secret is involved.
 */
export class FirebasePhoneTokenVerifier implements PhoneTokenVerifier {
  constructor(
    projectId: string,
    private readonly decode: (token: string) => Promise<DecodedIdToken> = (token) =>
      getAuth(appFor(projectId)).verifyIdToken(token),
  ) {}

  async verify(token: string): Promise<VerifiedPhone | null> {
    let decoded: DecodedIdToken;
    try {
      decoded = await this.decode(token);
    } catch (error) {
      if (isTokenError(error)) return null;
      throw new ServiceUnavailableException();
    }
    const phone = decoded.phone_number;
    if (decoded.firebase.sign_in_provider !== 'phone' || !phone || !PHONE_FORMAT.test(phone)) {
      return null;
    }
    return { phone, verifiedAt: new Date(decoded.auth_time * 1000) };
  }
}

/** Without FIREBASE_PROJECT_ID this server does not accept Firebase sign-ins. */
export class DisabledPhoneTokenVerifier implements PhoneTokenVerifier {
  verify(): Promise<VerifiedPhone | null> {
    return Promise.reject(
      new BusinessRuleViolation(
        'metodo_no_disponible',
        'Este servidor no tiene habilitado el ingreso con Firebase.',
        'conflict',
      ),
    );
  }
}
