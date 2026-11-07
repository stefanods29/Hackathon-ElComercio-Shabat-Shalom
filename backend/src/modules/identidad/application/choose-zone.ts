import { Inject, Injectable } from '@nestjs/common';
import type { Actor } from '../../../shared/auth/actor.js';
import { TokenService } from '../../../shared/auth/token.service.js';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { BusinessRuleViolation, ResourceNotFound } from '../../../shared/domain/errors.js';
import type { IssuedSession } from './issue-credentials.js';
import {
  USER_REPOSITORY,
  ZONE_REPOSITORY,
  type RegisteredUser,
  type UserRepository,
  type ZoneRepository,
} from './ports.js';

type Choice =
  | { readonly kind: 'missing' }
  | { readonly kind: 'already_chosen' }
  | { readonly kind: 'chosen'; readonly user: RegisteredUser };

@Injectable()
export class ChooseZone {
  constructor(
    @Inject(UNIT_OF_WORK) private readonly unitOfWork: UnitOfWork,
    @Inject(ZONE_REPOSITORY) private readonly zones: ZoneRepository,
    @Inject(USER_REPOSITORY) private readonly users: UserRepository,
    private readonly tokens: TokenService,
  ) {}

  async execute(actor: Actor, zoneId: string): Promise<IssuedSession> {
    const choice = await this.unitOfWork.run(async (transaction): Promise<Choice> => {
      if (!(await this.zones.exists(transaction, zoneId))) return { kind: 'missing' };
      const user = await this.users.assignZone(transaction, actor.id, zoneId);
      return user ? { kind: 'chosen', user } : { kind: 'already_chosen' };
    });

    if (choice.kind === 'missing') {
      throw new ResourceNotFound('la zona', zoneId);
    }
    if (choice.kind === 'already_chosen') {
      throw new BusinessRuleViolation('zona_ya_elegida', 'Ya elegiste tu zona.', 'conflict');
    }

    const { token, expiresAt } = await this.tokens.issueAccess(choice.user);
    return { accessToken: token, expiresAt, user: choice.user };
  }
}
