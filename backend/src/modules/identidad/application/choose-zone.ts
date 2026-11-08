import { Inject, Injectable } from '@nestjs/common';
import type { Actor } from '../../../shared/auth/actor.js';
import { TokenService } from '../../../shared/auth/token.service.js';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { AuthenticationFailure, ResourceNotFound } from '../../../shared/domain/errors.js';
import { OUTBOX_WRITER, type OutboxWriter } from '../../../shared/outbox/outbox.js';
import { ensureZoneChangeAllowed } from '../domain/residence.js';
import { IDENTITY_MODULE, zoneChanged } from './identity-events.js';
import type { IssuedSession } from './issue-credentials.js';
import {
  USER_REPOSITORY,
  ZONE_REPOSITORY,
  type UserRepository,
  type ZoneRepository,
} from './ports.js';
import { RESIDENCE_STORE, type ResidenceStore } from './residence-store.js';
import { SESSION_REPOSITORY, type SessionRepository } from './session-ports.js';

@Injectable()
export class ChooseZone {
  constructor(
    @Inject(UNIT_OF_WORK) private readonly unitOfWork: UnitOfWork,
    @Inject(ZONE_REPOSITORY) private readonly zones: ZoneRepository,
    @Inject(USER_REPOSITORY) private readonly users: UserRepository,
    @Inject(RESIDENCE_STORE) private readonly residence: ResidenceStore,
    @Inject(OUTBOX_WRITER) private readonly outbox: OutboxWriter,
    private readonly tokens: TokenService,
    @Inject(SESSION_REPOSITORY) private readonly sessions: SessionRepository,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  async execute(actor: Actor, zoneId: string): Promise<IssuedSession> {
    return this.unitOfWork.run(async (tx) => {
      await this.sessions.lockUser(tx, actor.id);
      const now = this.clock.now();
      if (
        actor.sessionId &&
        !(await this.sessions.hasActiveFamily(tx, actor.id, actor.sessionId, now))
      ) {
        throw new AuthenticationFailure(
          'sesion_revocada',
          'La sesión fue revocada o venció. Inicia sesión de nuevo.',
        );
      }
      const account = await this.residence.findActive(tx, actor.id);
      if (!account)
        throw new AuthenticationFailure('sesion_revocada', 'La cuenta ya no está activa.');
      if (zoneId !== account.zoneId) {
        if (!(await this.zones.exists(tx, zoneId))) throw new ResourceNotFound('la zona', zoneId);
        if (account.zoneId) ensureZoneChangeAllowed(account.zoneChosenAt, now);
        await this.residence.changeZone(tx, actor.id, zoneId, now);
        if (account.zoneId) {
          await this.outbox.record(tx, IDENTITY_MODULE, [
            zoneChanged(actor.id, account.zoneId, zoneId, now),
          ]);
        }
      }
      const user = await this.users.findById(actor.id, tx);
      if (!user) throw new AuthenticationFailure('sesion_revocada', 'La cuenta ya no está activa.');
      const { token, expiresAt } = await this.tokens.issueAccess({
        ...user,
        sessionId: actor.sessionId,
      });
      return { accessToken: token, expiresAt, user };
    });
  }
}
