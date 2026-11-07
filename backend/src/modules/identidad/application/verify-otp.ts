import { createHmac, timingSafeEqual } from 'node:crypto';
import { Inject, Injectable } from '@nestjs/common';
import { TokenService } from '../../../shared/auth/token.service.js';
import { APP_CONFIG, type AppConfig } from '../../../shared/config/app-config.js';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { AuthenticationFailure, RateLimitExceeded } from '../../../shared/domain/errors.js';
import type { IssuedSession } from './issue-credentials.js';
import {
  OTP_CODE_REPOSITORY,
  USER_REPOSITORY,
  type OtpCodeRecord,
  type OtpCodeRepository,
  type RegisteredUser,
  type UserRepository,
} from './ports.js';

export interface VerifyOtpCommand {
  readonly phone: string;
  readonly code: string;
  readonly device?: string;
}

type Verification =
  | { readonly kind: 'invalid' }
  | { readonly kind: 'locked'; readonly retryAfterSeconds: number }
  | { readonly kind: 'ok'; readonly user: RegisteredUser };

@Injectable()
export class VerifyOtp {
  constructor(
    @Inject(UNIT_OF_WORK) private readonly unitOfWork: UnitOfWork,
    @Inject(OTP_CODE_REPOSITORY) private readonly codes: OtpCodeRepository,
    @Inject(USER_REPOSITORY) private readonly users: UserRepository,
    private readonly tokens: TokenService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  async execute(command: VerifyOtpCommand): Promise<IssuedSession> {
    const now = this.clock.now();
    const verification = await this.unitOfWork.run(async (transaction): Promise<Verification> => {
      const record = await this.codes.findLatestActiveForUpdate(transaction, command.phone, now);
      if (!record) return { kind: 'invalid' };
      if (record.attempts >= this.config.OTP_MAX_ATTEMPTS) {
        return this.locked(record, now);
      }

      const expected = Buffer.from(record.codeHash, 'hex');
      const received = Buffer.from(
        createHmac('sha256', this.config.OTP_HASH_SECRET)
          .update(`${command.phone}:${command.code}`)
          .digest('hex'),
        'hex',
      );
      if (expected.length !== received.length || !timingSafeEqual(expected, received)) {
        await this.codes.incrementAttempts(transaction, record.id);
        return { kind: 'invalid' };
      }

      if (!(await this.codes.markUsed(transaction, record.id, now))) {
        return { kind: 'invalid' };
      }
      const user = await this.users.findOrCreateByPhone(transaction, command.phone);
      return { kind: 'ok', user };
    });

    if (verification.kind === 'invalid') {
      throw new AuthenticationFailure(
        'codigo_invalido',
        'El código no es válido, ya venció o ya fue utilizado.',
      );
    }
    if (verification.kind === 'locked') {
      throw new RateLimitExceeded(
        'demasiados_intentos',
        'Superaste el límite de intentos. Intenta de nuevo más tarde.',
        verification.retryAfterSeconds,
      );
    }

    const { token, expiresAt } = await this.tokens.issueAccess(verification.user);
    return { accessToken: token, expiresAt, user: verification.user };
  }

  private locked(record: OtpCodeRecord, now: Date): Verification {
    const lockedUntil = record.createdAt.getTime() + this.config.OTP_LOCK_MINUTES * 60_000;
    return {
      kind: 'locked',
      retryAfterSeconds: Math.max(1, Math.ceil((lockedUntil - now.getTime()) / 1000)),
    };
  }
}
