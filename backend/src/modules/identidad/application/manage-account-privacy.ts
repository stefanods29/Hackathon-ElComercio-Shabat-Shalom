import { Inject, Injectable } from '@nestjs/common';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { AuthenticationFailure } from '../../../shared/domain/errors.js';
import { OUTBOX_WRITER, type OutboxWriter } from '../../../shared/outbox/outbox.js';
import { PersonalDataRegistry } from '../../../shared/privacy/personal-data.registry.js';
import { ACCOUNT_PRIVACY_STORE, type AccountPrivacyStore } from './account-privacy-store.js';
import { IDENTITY_MODULE, accountDeleted } from './identity-events.js';
import { OTP_CODE_REPOSITORY, type OtpCodeRepository } from './ports.js';
import { RESIDENCE_STORE, type ResidenceStore } from './residence-store.js';
import { SESSION_REPOSITORY, type SessionRepository } from './session-ports.js';

@Injectable()
export class ManageAccountPrivacy {
  constructor(
    @Inject(UNIT_OF_WORK) private readonly unitOfWork: UnitOfWork,
    @Inject(CLOCK) private readonly clock: Clock,
    @Inject(ACCOUNT_PRIVACY_STORE) private readonly accounts: AccountPrivacyStore,
    @Inject(RESIDENCE_STORE) private readonly residence: ResidenceStore,
    @Inject(SESSION_REPOSITORY) private readonly sessions: SessionRepository,
    @Inject(OTP_CODE_REPOSITORY) private readonly otp: OtpCodeRepository,
    @Inject(OUTBOX_WRITER) private readonly outbox: OutboxWriter,
    private readonly registry: PersonalDataRegistry,
  ) {}

  export(userId: string) {
    return this.unitOfWork.run(async (tx) => {
      await this.sessions.lockUser(tx, userId);
      if (!(await this.residence.findActive(tx, userId))) {
        throw new AuthenticationFailure('sesion_revocada', 'La cuenta ya no está activa.');
      }
      return {
        generadoEn: this.clock.now().toISOString(),
        modulos: await this.registry.export(tx, userId),
      };
    });
  }

  rectify(userId: string, displayName: string): Promise<void> {
    return this.unitOfWork.run(async (tx) => {
      await this.sessions.lockUser(tx, userId);
      if (!(await this.accounts.rectify(tx, userId, displayName, this.clock.now()))) {
        throw new AuthenticationFailure('sesion_revocada', 'La cuenta ya no está activa.');
      }
    });
  }

  requestDeletion(userId: string): Promise<void> {
    return this.unitOfWork.run(async (tx) => {
      await this.sessions.lockUser(tx, userId);
      const now = this.clock.now();
      if (!(await this.accounts.markDeleted(tx, userId, now))) return;
      await this.sessions.revokeAll(tx, userId, now);
      await this.outbox.record(tx, IDENTITY_MODULE, [accountDeleted(userId, now)]);
    });
  }

  eraseDeletedAccount(userId: string, requestedAt: Date): Promise<void> {
    return this.unitOfWork.run(async (tx) => {
      const phone = await this.accounts.findPendingPhone(tx, userId);
      if (!phone) return;
      // OTP verification takes the same locks in this order.
      await this.otp.lockPhoneAndIp(tx, phone, null);
      await this.sessions.lockUser(tx, userId);
      if (!(await this.accounts.findPendingPhone(tx, userId, true))) return;
      await this.registry.erase(tx, { userId, requestedAt });
    });
  }
}
