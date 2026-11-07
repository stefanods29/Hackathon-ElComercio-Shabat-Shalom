import { Inject, Injectable } from '@nestjs/common';
import { TokenService } from '../../../shared/auth/token.service.js';
import type { Actor } from '../../../shared/auth/actor.js';
import { APP_CONFIG, type AppConfig } from '../../../shared/config/app-config.js';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import {
  AuthenticationFailure,
  BusinessRuleViolation,
  ResourceNotFound,
} from '../../../shared/domain/errors.js';
import { type RegisteredUser, USER_REPOSITORY, type UserRepository } from './ports.js';
import { SESSION_REPOSITORY, type SessionRepository } from './session-ports.js';

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
 * Development access and session-aware PowerSync credentials. OTP creates revocable sessions.
 */
@Injectable()
export class IssueCredentials {
  constructor(
    @Inject(USER_REPOSITORY) private readonly users: UserRepository,
    private readonly tokens: TokenService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Inject(UNIT_OF_WORK) private readonly unitOfWork: UnitOfWork,
    @Inject(SESSION_REPOSITORY) private readonly sessions: SessionRepository,
    @Inject(CLOCK) private readonly clock: Clock,
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
  async forSync(actor: Actor): Promise<SyncCredentials> {
    return this.unitOfWork.run(async (transaction) => {
      if (actor.sessionId) {
        await this.sessions.lockUser(transaction, actor.id);
        if (
          !(await this.sessions.hasActiveFamily(
            transaction,
            actor.id,
            actor.sessionId,
            this.clock.now(),
          ))
        ) {
          throw new AuthenticationFailure(
            'sesion_revocada',
            'La sesión fue revocada o venció. Inicia sesión de nuevo.',
          );
        }
      }
      const user = await this.users.findById(actor.id, transaction);
      if (!user) {
        throw new BusinessRuleViolation(
          'usuario_no_disponible',
          'Tu cuenta ya no está activa.',
          'forbidden',
        );
      }
      const { token, expiresAt } = await this.tokens.issueSync(user);
      return { endpoint: this.config.POWERSYNC_URL, token, expiresAt };
    });
  }
}
