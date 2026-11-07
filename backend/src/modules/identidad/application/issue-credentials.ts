import { Inject, Injectable } from '@nestjs/common';
import { TokenService } from '../../../shared/auth/token.service.js';
import { APP_CONFIG, type AppConfig } from '../../../shared/config/app-config.js';
import { BusinessRuleViolation, ResourceNotFound } from '../../../shared/domain/errors.js';
import { type RegisteredUser, USER_REPOSITORY, type UserRepository } from './ports.js';

export interface IssuedSession {
  readonly accessToken: string;
  readonly expiresAt: Date;
  readonly user: RegisteredUser;
}

export interface SyncCredentials {
  /** URL of the PowerSync service the phone must use. */
  readonly endpoint: string;
  readonly token: string;
  readonly expiresAt: Date;
}

/**
 * Token issuing. In Phase 0 a session starts with the phone number of a seeded user
 * (development only); Lot B replaces it with OTP + rotating refresh token.
 */
@Injectable()
export class IssueCredentials {
  constructor(
    @Inject(USER_REPOSITORY) private readonly users: UserRepository,
    private readonly tokens: TokenService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  async startDevSession(phone: string): Promise<IssuedSession> {
    if (!this.config.ENABLE_DEV_SESSION) {
      throw new ResourceNotFound('la ruta', '/v1/dev/sesiones');
    }
    const user = await this.users.findByPhone(phone);
    if (!user) {
      throw new ResourceNotFound('un usuario con el teléfono', phone);
    }
    const { token, expiresAt } = await this.tokens.issueAccess(user);
    return { accessToken: token, expiresAt, user };
  }

  /**
   * Credentials for PowerSync. Zone and trust level are read again from the database: if the
   * neighbor's zone or level changed, the Sync Streams reflect it on the next renewal.
   */
  async forSync(userId: string): Promise<SyncCredentials> {
    const user = await this.users.findById(userId);
    if (!user) {
      throw new BusinessRuleViolation(
        'usuario_no_disponible',
        'Tu cuenta ya no está activa.',
        'forbidden',
      );
    }
    const { token, expiresAt } = await this.tokens.issueSync(user);
    return { endpoint: this.config.POWERSYNC_URL, token, expiresAt };
  }
}
