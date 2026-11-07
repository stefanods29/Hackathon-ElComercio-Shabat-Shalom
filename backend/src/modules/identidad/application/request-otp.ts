import { createHmac, randomInt } from 'node:crypto';
import { Inject, Injectable } from '@nestjs/common';
import { APP_CONFIG, type AppConfig } from '../../../shared/config/app-config.js';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { RateLimitExceeded } from '../../../shared/domain/errors.js';
import { newId } from '../../../shared/domain/ids.js';
import {
  OTP_CODE_REPOSITORY,
  OTP_PROVIDER,
  type OtpChannel,
  type OtpCodeRepository,
  type OtpProvider,
} from './ports.js';

const PHONE_WINDOW_MS = 15 * 60_000;
const IP_WINDOW_MS = 60 * 60_000;

export interface RequestOtpCommand {
  readonly phone: string;
  readonly channel: OtpChannel;
  readonly ip: string | null;
}

export interface RequestOtpResult {
  readonly retryAfterSeconds: number;
  readonly expiresInSeconds: number;
}

type Preparation =
  | { readonly kind: 'ready'; readonly code: string }
  | { readonly kind: 'limited'; readonly retryAfterSeconds: number };

function windowRetryAfter(oldest: Date | null, windowMs: number, now: Date): number {
  const startedAt = oldest?.getTime() ?? now.getTime();
  return Math.max(1, Math.ceil((startedAt + windowMs - now.getTime()) / 1000));
}

@Injectable()
export class RequestOtp {
  constructor(
    @Inject(UNIT_OF_WORK) private readonly unitOfWork: UnitOfWork,
    @Inject(OTP_CODE_REPOSITORY) private readonly codes: OtpCodeRepository,
    @Inject(OTP_PROVIDER) private readonly provider: OtpProvider,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  async execute(command: RequestOtpCommand): Promise<RequestOtpResult> {
    const now = this.clock.now();
    const preparation = await this.unitOfWork.run(async (transaction) => {
      await this.codes.lockRequestWindow(transaction, command.phone, command.ip);

      const phoneUsage = await this.codes.countByPhoneSince(
        command.phone,
        new Date(now.getTime() - PHONE_WINDOW_MS),
        transaction,
      );
      if (phoneUsage.count >= this.config.OTP_MAX_REQUESTS_PER_PHONE) {
        return {
          kind: 'limited',
          retryAfterSeconds: windowRetryAfter(phoneUsage.oldest, PHONE_WINDOW_MS, now),
        } satisfies Preparation;
      }

      if (command.ip) {
        const ipUsage = await this.codes.countByIpSince(
          command.ip,
          new Date(now.getTime() - IP_WINDOW_MS),
          transaction,
        );
        if (ipUsage.count >= this.config.OTP_MAX_REQUESTS_PER_IP) {
          return {
            kind: 'limited',
            retryAfterSeconds: windowRetryAfter(ipUsage.oldest, IP_WINDOW_MS, now),
          } satisfies Preparation;
        }
      }

      const code = randomInt(0, 1_000_000).toString().padStart(6, '0');
      const codeHash = createHmac('sha256', this.config.OTP_HASH_SECRET)
        .update(`${command.phone}:${code}`)
        .digest('hex');
      await this.codes.create(transaction, {
        id: newId(),
        phone: command.phone,
        codeHash,
        channel: command.channel,
        ip: command.ip,
        attempts: 0,
        expiresAt: new Date(now.getTime() + this.config.OTP_TTL_MINUTES * 60_000),
        usedAt: null,
        createdAt: now,
      });
      return { kind: 'ready', code } satisfies Preparation;
    });

    if (preparation.kind === 'limited') {
      throw new RateLimitExceeded(
        'demasiados_intentos',
        'Superaste el límite de solicitudes. Intenta de nuevo más tarde.',
        preparation.retryAfterSeconds,
      );
    }

    await this.provider.send(command.phone, preparation.code, command.channel);
    return {
      retryAfterSeconds: 60,
      expiresInSeconds: this.config.OTP_TTL_MINUTES * 60,
    };
  }
}
