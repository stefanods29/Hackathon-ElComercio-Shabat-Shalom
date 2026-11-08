import { Inject, Injectable } from '@nestjs/common';
import { AccountAccess } from '../../../shared/auth/account-access.js';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { ResourceNotFound } from '../../../shared/domain/errors.js';
import {
  CONTENT_APPROVED,
  CONTENT_HIDDEN,
  CONTENT_RESTORED,
  ContentModerationRegistry,
} from '../../../shared/moderation/content-moderation.js';
import { type Decision, type ModerationCase, SUSPENSION_MS } from '../domain/moderation.js';
import { ModerationEvents } from './moderation-events.js';
import { MODERATION_STORE, type ModerationStore } from './ports.js';

@Injectable()
export class DecideCase {
  constructor(
    @Inject(UNIT_OF_WORK) private readonly unitOfWork: UnitOfWork,
    @Inject(CLOCK) private readonly clock: Clock,
    @Inject(MODERATION_STORE) private readonly store: ModerationStore,
    private readonly accounts: AccountAccess,
    private readonly content: ContentModerationRegistry,
    private readonly events: ModerationEvents,
  ) {}

  execute(
    caseId: string,
    moderatorId: string,
    action: Decision,
    reason: string,
  ): Promise<ModerationCase> {
    return this.unitOfWork.run(async (tx) => {
      await this.accounts.requireActiveWrite(tx, moderatorId);
      const found = await this.store.findCase(tx, caseId);
      if (!found) throw new ResourceNotFound('el caso', caseId);
      const ref = found.content;
      await this.store.lockContent(tx, ref);
      const target =
        action === 'descartar' ? null : await this.content.owner(ref.type).read(tx, ref);
      if (!target && action !== 'descartar') throw new ResourceNotFound('el contenido', ref.id);
      const now = this.clock.now();
      const { moderationCase, decisionId } = await this.store.resolve(
        tx,
        caseId,
        moderatorId,
        action,
        reason,
        now,
      );
      if (action === 'sancionar' && target) {
        await this.accounts.requireActiveWrite(tx, target.ownerId);
        await this.store.suspend(
          tx,
          target.ownerId,
          decisionId,
          now,
          new Date(now.getTime() + SUSPENSION_MS),
        );
        await this.events.visibility(tx, ref, CONTENT_HIDDEN, 'sancionado', now);
      } else if (action === 'ocultar') {
        await this.events.visibility(tx, ref, CONTENT_HIDDEN, 'moderado', now);
      } else if (action === 'restaurar') {
        await this.events.visibility(tx, ref, CONTENT_RESTORED, 'restaurado', now);
      } else if (action === 'publicar') {
        await this.events.visibility(tx, ref, CONTENT_APPROVED, 'aprobado', now);
      }
      return moderationCase;
    });
  }
}
