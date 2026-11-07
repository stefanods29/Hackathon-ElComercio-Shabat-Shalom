import { Inject, Injectable } from '@nestjs/common';
import type { Actor } from '../../../shared/auth/actor.js';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { SESSION_REPOSITORY, type SessionRepository } from './session-ports.js';

@Injectable()
export class RevokeAllSessions {
  constructor(
    @Inject(UNIT_OF_WORK) private readonly unitOfWork: UnitOfWork,
    @Inject(SESSION_REPOSITORY) private readonly sessions: SessionRepository,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  async execute(actor: Actor): Promise<void> {
    await this.unitOfWork.run(async (transaction) => {
      await this.sessions.lockUser(transaction, actor.id);
      await this.sessions.revokeAll(transaction, actor.id, this.clock.now());
    });
  }
}
