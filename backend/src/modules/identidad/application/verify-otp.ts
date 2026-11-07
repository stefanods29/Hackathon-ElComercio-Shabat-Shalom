import { createHmac, timingSafeEqual } from 'node:crypto';
import { Inject, Injectable } from '@nestjs/common';
import { TokenService } from '../../../shared/auth/token.service.js';
import { APP_CONFIG, type AppConfig } from '../../../shared/config/app-config.js';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { AuthenticationFailure, RateLimitExceeded } from '../../../shared/domain/errors.js';
import type { IssuedSession } from './issue-credentials.js';
import { failureRetryAfter, nextFailureState } from './otp-failure-policy.js';
import {
  OTP_CODE_REPOSITORY,
  USER_REPOSITORY,
  type OtpCodeRepository,
  type RegisteredUser,
  type UserRepository,
} from './ports.js';

export interface VerifyOtpCommand {
  readonly phone: string;
  readonly code: string;
  readonly ip: string | null;
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
    const verification = await this.unitOfWork.run(async (transaction): Promise<Verification> => {
      const ip = await this.codes.lockPhoneAndIp(transaction, command.phone, command.ip);
      const now = this.clock.now();
      const phoneState = await this.codes.findFailureState(transaction, 'telefono', command.phone);
      const ipState = ip ? await this.codes.findFailureState(transaction, 'ip', ip) : null;
      const retryAfterSeconds = failureRetryAfter([phoneState, ipState], now);
      if (retryAfterSeconds > 0) return { kind: 'locked', retryAfterSeconds };

      const record = await this.codes.findLatestActiveForUpdate(transaction, command.phone, now);
      const expected = record ? Buffer.from(record.codeHash, 'hex') : null;
      const received = Buffer.from(
        createHmac('sha256', this.config.OTP_HASH_SECRET)
          .update(`${command.phone}:${command.code}`)
          .digest('hex'),
        'hex',
      );
      if (
        record &&
        expected &&
        expected.length === received.length &&
        timingSafeEqual(expected, received) &&
        (await this.codes.markUsed(transaction, record.id, now))
      ) {
        const user = await this.users.findOrCreateByPhone(transaction, command.phone);
        await this.codes.clearFailureState(transaction, 'telefono', command.phone);
        // A successful login must not erase failures made from this IP against other phones.
        return { kind: 'ok', user };
      }
      if (record) await this.codes.incrementAttempts(transaction, record.id);
      await this.codes.saveFailureState(
        transaction,
        'telefono',
        command.phone,
        nextFailureState(
          phoneState,
          now,
          this.config.OTP_MAX_ATTEMPTS,
          this.config.OTP_LOCK_MINUTES,
        ),
      );
      if (ip)
        await this.codes.saveFailureState(
          transaction,
          'ip',
          ip,
          nextFailureState(
            ipState,
            now,
            this.config.OTP_MAX_ATTEMPTS_PER_IP,
            this.config.OTP_LOCK_MINUTES,
          ),
        );
      return { kind: 'invalid' };
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
}
