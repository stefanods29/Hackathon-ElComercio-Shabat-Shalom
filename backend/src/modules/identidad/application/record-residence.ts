import { Inject, Injectable } from '@nestjs/common';
import type { Actor } from '../../../shared/auth/actor.js';
import {
  UNIT_OF_WORK,
  type TransactionContext,
  type UnitOfWork,
} from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import {
  AuthenticationFailure,
  BusinessRuleViolation,
  ResourceNotFound,
} from '../../../shared/domain/errors.js';
import { OUTBOX_WRITER, type OutboxWriter } from '../../../shared/outbox/outbox.js';
import { CONSENT_POLICIES } from '../domain/consents.js';
import {
  ensurePresenceDateAllowed,
  PRESENCE_WINDOW_DAYS,
  REQUIRED_ENDORSEMENTS,
  REQUIRED_PRESENCE_DAYS,
  residenceDay,
  residenceDayDaysAgo,
} from '../domain/residence.js';
import { IDENTITY_MODULE, residenceConfirmed } from './identity-events.js';
import { RESIDENCE_STORE, type ResidenceStore } from './residence-store.js';
import { SESSION_REPOSITORY, type SessionRepository } from './session-ports.js';

const PRESENCE_PURPOSE = 'confirmacion_por_presencia';

function requireZone(zoneId: string | null): string {
  if (!zoneId)
    throw new BusinessRuleViolation('zona_requerida', 'Primero elige una zona.', 'forbidden');
  return zoneId;
}

@Injectable()
export class RecordResidence {
  constructor(
    @Inject(UNIT_OF_WORK) private readonly unitOfWork: UnitOfWork,
    @Inject(CLOCK) private readonly clock: Clock,
    @Inject(RESIDENCE_STORE) private readonly residence: ResidenceStore,
    @Inject(SESSION_REPOSITORY) private readonly sessions: SessionRepository,
    @Inject(OUTBOX_WRITER) private readonly outbox: OutboxWriter,
  ) {}

  reportPresence(actor: Actor, day: string, inside: boolean): Promise<number> {
    const userId = actor.id;
    return this.unitOfWork.run(async (tx) => {
      await this.sessions.lockUser(tx, userId);
      const account = await this.residence.findActive(tx, userId);
      if (!account)
        throw new AuthenticationFailure('sesion_revocada', 'La cuenta ya no está activa.');
      const decision = await this.residence.latestConsent(tx, userId, PRESENCE_PURPOSE);
      if (!decision?.accepted || decision.version !== CONSENT_POLICIES[PRESENCE_PURPOSE].version) {
        throw new BusinessRuleViolation(
          'consentimiento_requerido',
          'Acepta el texto vigente de confirmación por presencia.',
          'forbidden',
        );
      }
      const zoneId = requireZone(account.zoneId);
      if (actor.zoneId !== zoneId) {
        throw new BusinessRuleViolation(
          'zona_requerida',
          'Actualiza tu sesión para informar presencia en tu zona actual.',
          'forbidden',
        );
      }
      const now = this.clock.now();
      ensurePresenceDateAllowed(day, account.zoneChosenAt, now);
      await this.residence.recordPresence(tx, userId, day, inside);
      if (account.level > 0) return account.level;
      const count = await this.residence.countPresenceDays(
        tx,
        userId,
        residenceDayDaysAgo(now, PRESENCE_WINDOW_DAYS - 1),
        residenceDay(now),
      );
      if (count < REQUIRED_PRESENCE_DAYS) return 0;
      await this.promote(tx, userId, zoneId, 1, 'presencia', now);
      return this.promoteFromEndorsements(tx, userId, zoneId, 1, now);
    });
  }

  confirmManually(
    moderatorId: string,
    userId: string,
    reason: string,
    level: 1 | 2,
  ): Promise<number> {
    return this.unitOfWork.run(async (tx) => {
      await this.lockUsers(tx, moderatorId, userId);
      const moderator = await this.residence.findActive(tx, moderatorId);
      if (!moderator?.isModerator) {
        throw new BusinessRuleViolation(
          'rol_requerido',
          'Para confirmar necesitas el rol moderador.',
          'forbidden',
          { rolesRequeridos: ['moderador'] },
        );
      }
      const account = await this.residence.findActive(tx, userId);
      if (!account) throw new ResourceNotFound('el vecino', userId);
      const zoneId = requireZone(account.zoneId);
      const now = this.clock.now();
      await this.residence.recordConfirmation(tx, userId, zoneId, moderatorId, reason, level, now);
      if (level > account.level) await this.promote(tx, userId, zoneId, level, 'manual', now);
      return this.promoteFromEndorsements(tx, userId, zoneId, Math.max(level, account.level), now);
    });
  }

  endorse(endorserId: string, userId: string): Promise<number> {
    if (endorserId === userId) {
      throw new BusinessRuleViolation(
        'no_puedes_avalarte',
        'No puedes avalarte a ti mismo.',
        'forbidden',
      );
    }
    return this.unitOfWork.run(async (tx) => {
      await this.lockUsers(tx, endorserId, userId);
      const endorser = await this.residence.findActive(tx, endorserId);
      if (!endorser)
        throw new AuthenticationFailure('sesion_revocada', 'La cuenta ya no está activa.');
      if (endorser.level < 2) {
        throw new BusinessRuleViolation(
          'nivel_de_confianza_insuficiente',
          'Para avalar necesitas nivel 2.',
          'forbidden',
          {
            nivelActual: endorser.level,
            nivelRequerido: 2,
          },
        );
      }
      const account = await this.residence.findActive(tx, userId);
      if (!account) throw new ResourceNotFound('el vecino', userId);
      if (!endorser.zoneId || account.zoneId !== endorser.zoneId) {
        throw new BusinessRuleViolation(
          'fuera_de_tu_zona',
          'Solo puedes avalar a un vecino de tu zona.',
          'forbidden',
        );
      }
      const now = this.clock.now();
      await this.residence.recordEndorsement(tx, userId, endorser.zoneId, endorserId, now);
      return this.promoteFromEndorsements(tx, userId, endorser.zoneId, account.level, now);
    });
  }

  private async lockUsers(tx: TransactionContext, ...ids: string[]): Promise<void> {
    for (const id of [...new Set(ids)].sort()) await this.sessions.lockUser(tx, id);
  }

  private async promoteFromEndorsements(
    tx: TransactionContext,
    userId: string,
    zoneId: string,
    level: number,
    now: Date,
  ): Promise<number> {
    if (
      level !== 1 ||
      (await this.residence.countEndorsements(tx, userId, zoneId)) < REQUIRED_ENDORSEMENTS
    )
      return level;
    await this.promote(tx, userId, zoneId, 2, 'avales', now);
    return 2;
  }

  private async promote(
    tx: TransactionContext,
    userId: string,
    zoneId: string,
    level: number,
    method: 'presencia' | 'manual' | 'avales',
    now: Date,
  ): Promise<void> {
    await this.residence.updateLevel(tx, userId, level, now);
    await this.outbox.record(tx, IDENTITY_MODULE, [
      residenceConfirmed(userId, zoneId, level, method, now),
    ]);
  }
}
