import { Inject, Injectable } from '@nestjs/common';
import { AccountAccess } from '../../../shared/auth/account-access.js';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { BusinessRuleViolation, ResourceNotFound } from '../../../shared/domain/errors.js';
import { ContentModerationRegistry } from '../../../shared/moderation/content-moderation.js';
import type { Report, ReportData } from '../domain/moderation.js';
import { ModerationEvents } from './moderation-events.js';
import { MODERATION_STORE, type ModerationStore } from './ports.js';

@Injectable()
export class ReportContent {
  constructor(
    @Inject(UNIT_OF_WORK) private readonly unitOfWork: UnitOfWork,
    @Inject(CLOCK) private readonly clock: Clock,
    @Inject(MODERATION_STORE) private readonly store: ModerationStore,
    private readonly accounts: AccountAccess,
    private readonly content: ContentModerationRegistry,
    private readonly events: ModerationEvents,
  ) {}

  execute(reporterId: string, data: ReportData): Promise<{ report: Report; created: boolean }> {
    return this.unitOfWork.run(async (tx) => {
      await this.accounts.requireActiveWrite(tx, reporterId);
      await this.store.lockReport(tx, data.id);
      const existing = await this.store.findReport(tx, data.id);
      if (existing) {
        if (
          existing.reporterId === reporterId &&
          existing.content.type === data.content.type &&
          existing.content.id === data.content.id &&
          existing.reason === data.reason &&
          existing.details === data.details
        ) {
          return { report: existing, created: false };
        }
        throw new BusinessRuleViolation(
          'id_en_uso',
          'Ese id de denuncia ya está en uso.',
          'conflict',
        );
      }
      await this.store.lockContent(tx, data.content);
      const target = await this.content.owner(data.content.type).read(tx, data.content);
      if (!target) throw new ResourceNotFound('el contenido', data.content.id);
      const now = this.clock.now();
      const pending = await this.store.openCase(
        tx,
        data.content,
        target.ownerId,
        data.reason,
        now,
        true,
      );
      const report = await this.store.saveReport(tx, data, reporterId, pending.id, now);
      await this.events.reportCreated(tx, report.id, now);
      return { report, created: true };
    });
  }
}
