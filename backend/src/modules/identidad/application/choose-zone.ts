import { Inject, Injectable } from '@nestjs/common';
import type { Actor } from '../../../shared/auth/actor.js';
import { TokenService } from '../../../shared/auth/token.service.js';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import {
  AuthenticationFailure,
  BusinessRuleViolation,
  ResourceNotFound,
} from '../../../shared/domain/errors.js';
import type { IssuedSession } from './issue-credentials.js';
import {
  USER_REPOSITORY,
  ZONE_REPOSITORY,
  type UserRepository,
  type ZoneRepository,
} from './ports.js';
import { SESSION_REPOSITORY, type SessionRepository } from './session-ports.js';

type Choice =
  | { readonly kind: 'missing' }
  | { readonly kind: 'already_chosen' }
  | { readonly kind: 'revoked' }
  | { readonly kind: 'chosen'; readonly session: IssuedSession };

@Injectable()
export class ChooseZone {
  constructor(
    @Inject(UNIT_OF_WORK) private readonly unitOfWork: UnitOfWork,
    @Inject(ZONE_REPOSITORY) private readonly zones: ZoneRepository,
    @Inject(USER_REPOSITORY) private readonly users: UserRepository,
    private readonly tokens: TokenService,
    @Inject(SESSION_REPOSITORY) private readonly sessions: SessionRepository,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  async execute(actor: Actor, zoneId: string): Promise<IssuedSession> {
    const choice = await this.unitOfWork.run(async (transaction): Promise<Choice> => {
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
          return { kind: 'revoked' };
        }
      }
      if (!(await this.zones.exists(transaction, zoneId))) return { kind: 'missing' };
      const user = await this.users.assignZone(transaction, actor.id, zoneId);
      if (!user) return { kind: 'already_chosen' };
      const { token, expiresAt } = await this.tokens.issueAccess({
        ...user,
        sessionId: actor.sessionId,
      });
      return { kind: 'chosen', session: { accessToken: token, expiresAt, user } };
    });

    if (choice.kind === 'revoked') {
      throw new AuthenticationFailure(
        'sesion_revocada',
        'La sesión fue revocada o venció. Inicia sesión de nuevo.',
      );
    }
    if (choice.kind === 'missing') {
      throw new ResourceNotFound('la zona', zoneId);
    }
    if (choice.kind === 'already_chosen') {
      throw new BusinessRuleViolation('zona_ya_elegida', 'Ya elegiste tu zona.', 'conflict');
    }

    return choice.session;
  }
}
