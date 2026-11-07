import { createHmac, randomBytes } from 'node:crypto';
import { Inject, Injectable } from '@nestjs/common';
import { TokenService } from '../../../shared/auth/token.service.js';
import { APP_CONFIG, type AppConfig } from '../../../shared/config/app-config.js';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { newId } from '../../../shared/domain/ids.js';
import type { IssuedSession } from './issue-credentials.js';
import type { RegisteredUser } from './ports.js';
import { SESSION_REPOSITORY, type SessionRepository } from './session-ports.js';

export interface IssuedRefreshSession extends IssuedSession {
  readonly refreshToken: string;
  readonly refreshExpiresAt: Date;
}

export function hashRefreshToken(token: string, secret: string): string {
  return createHmac('sha256', secret).update(token).digest('hex');
}

@Injectable()
export class CreateSession {
  constructor(
    @Inject(SESSION_REPOSITORY) private readonly sessions: SessionRepository,
    private readonly tokens: TokenService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  /** Shares the caller's transaction: OTP consumption or rotation rolls back if issuing fails. */
  async inTransaction(
    transaction: TransactionContext,
    user: RegisteredUser,
    device: string | null,
    familyId = newId(),
  ): Promise<IssuedRefreshSession> {
    await this.sessions.lockUser(transaction, user.id);
    const now = this.clock.now();
    const refreshToken = randomBytes(32).toString('base64url');
    const refreshExpiresAt = new Date(now.getTime() + this.config.REFRESH_TOKEN_DAYS * 86_400_000);
    await this.sessions.create(transaction, {
      id: newId(),
      userId: user.id,
      familyId,
      refreshHash: hashRefreshToken(refreshToken, this.config.REFRESH_TOKEN_SECRET),
      device,
      createdAt: now,
      expiresAt: refreshExpiresAt,
      rotatedAt: null,
      revokedAt: null,
      reason: null,
    });
    const { token, expiresAt } = await this.tokens.issueAccess({ ...user, sessionId: familyId });
    return { accessToken: token, expiresAt, user, refreshToken, refreshExpiresAt };
  }
}
