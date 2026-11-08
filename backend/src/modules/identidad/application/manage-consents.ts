import { Inject, Injectable } from '@nestjs/common';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { AuthenticationFailure, BusinessRuleViolation } from '../../../shared/domain/errors.js';
import { CONSENT_POLICIES, CONSENT_PURPOSES, type ConsentPurpose } from '../domain/consents.js';
import { type ConsentDecision, RESIDENCE_STORE, type ResidenceStore } from './residence-store.js';
import { SESSION_REPOSITORY, type SessionRepository } from './session-ports.js';

function toState(purpose: ConsentPurpose, decision: ConsentDecision | null) {
  const policy = CONSENT_POLICIES[purpose];
  return {
    finalidad: purpose,
    versionVigente: policy.version,
    obligatoria: policy.required,
    decision: decision && {
      version: decision.version,
      aceptado: decision.accepted,
      decididoEn: decision.decidedAt.toISOString(),
    },
  };
}

@Injectable()
export class ManageConsents {
  constructor(
    @Inject(UNIT_OF_WORK) private readonly unitOfWork: UnitOfWork,
    @Inject(CLOCK) private readonly clock: Clock,
    @Inject(RESIDENCE_STORE) private readonly residence: ResidenceStore,
    @Inject(SESSION_REPOSITORY) private readonly sessions: SessionRepository,
  ) {}

  list(userId: string) {
    return this.unitOfWork.run(async (tx) => {
      await this.sessions.lockUser(tx, userId);
      if (!(await this.residence.findActive(tx, userId))) {
        throw new AuthenticationFailure('sesion_revocada', 'La cuenta ya no está activa.');
      }
      return Promise.all(
        CONSENT_PURPOSES.map(async (purpose) =>
          toState(purpose, await this.residence.latestConsent(tx, userId, purpose)),
        ),
      );
    });
  }

  decide(userId: string, purpose: ConsentPurpose, version: number, accepted: boolean) {
    return this.unitOfWork.run(async (tx) => {
      await this.sessions.lockUser(tx, userId);
      if (!(await this.residence.findActive(tx, userId))) {
        throw new AuthenticationFailure('sesion_revocada', 'La cuenta ya no está activa.');
      }
      const { version: currentVersion } = CONSENT_POLICIES[purpose];
      if (version !== currentVersion) {
        throw new BusinessRuleViolation(
          'version_de_consentimiento_desactualizada',
          'Lee la versión vigente del consentimiento.',
          'conflict',
          { versionVigente: currentVersion },
        );
      }
      const decision = { version, accepted, decidedAt: this.clock.now() };
      await this.residence.recordConsent(tx, userId, purpose, decision);
      if (purpose === 'confirmacion_por_presencia' && !accepted) {
        await this.residence.clearPresences(tx, userId);
      }
      return toState(purpose, decision);
    });
  }
}
