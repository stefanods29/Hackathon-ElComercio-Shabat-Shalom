import { Inject, Injectable } from '@nestjs/common';
import { APP_CONFIG, type AppConfig } from '../../../shared/config/app-config.js';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { AuthenticationFailure } from '../../../shared/domain/errors.js';
import { CreateSession, hashRefreshToken, type IssuedRefreshSession } from './create-session.js';
import { USER_REPOSITORY, type UserRepository } from './ports.js';
import { SESSION_REPOSITORY, type SessionRepository } from './session-ports.js';

type RefreshResult =
  | { readonly kind: 'invalid' | 'revoked' | 'reused' }
  | { readonly kind: 'ok'; readonly session: IssuedRefreshSession };

@Injectable()
export class RefreshSession {
  constructor(
    @Inject(UNIT_OF_WORK) private readonly unitOfWork: UnitOfWork,
    @Inject(SESSION_REPOSITORY) private readonly sessions: SessionRepository,
    @Inject(USER_REPOSITORY) private readonly users: UserRepository,
    private readonly createSession: CreateSession,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  async execute(refreshToken: string): Promise<IssuedRefreshSession> {
    const hash = hashRefreshToken(refreshToken, this.config.REFRESH_TOKEN_SECRET);
    const result = await this.unitOfWork.run(async (transaction): Promise<RefreshResult> => {
      // Discover the owner without a row lock, then always lock user -> session to avoid deadlocks.
      const candidate = await this.sessions.findByHash(transaction, hash);
      if (!candidate) return { kind: 'invalid' };
      await this.sessions.lockUser(transaction, candidate.userId);
      const record = await this.sessions.findByHashForUpdate(transaction, hash);
      if (!record) return { kind: 'invalid' };
      const now = this.clock.now();
      if (record.revokedAt) return { kind: 'revoked' };
      if (record.rotatedAt) {
        await this.sessions.revokeFamily(
          transaction,
          record.userId,
          record.familyId,
          now,
          'reutilizacion',
        );
        return { kind: 'reused' };
      }
      if (record.expiresAt.getTime() <= now.getTime()) return { kind: 'invalid' };
      const user = await this.users.findById(record.userId, transaction);
      if (!user) {
        await this.sessions.revokeFamily(
          transaction,
          record.userId,
          record.familyId,
          now,
          'revocacion_total',
        );
        return { kind: 'revoked' };
      }
      await this.sessions.markRotated(transaction, record.id, now);
      const session = await this.createSession.inTransaction(
        transaction,
        user,
        record.device,
        record.familyId,
      );
      return { kind: 'ok', session };
    });
    // Reuse revocation MUST commit before the 401 is thrown.
    if (result.kind === 'ok') return result.session;
    if (result.kind === 'invalid') {
      throw new AuthenticationFailure(
        'sesion_invalida',
        'La sesión no es válida o ya venció. Inicia sesión de nuevo.',
      );
    }
    throw new AuthenticationFailure(
      'sesion_revocada',
      'La sesión fue revocada. Inicia sesión de nuevo.',
    );
  }
}
