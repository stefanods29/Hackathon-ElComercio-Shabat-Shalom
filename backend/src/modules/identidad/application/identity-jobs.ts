import { Inject, Injectable, type OnModuleInit } from '@nestjs/common';
import { z } from 'zod';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { JobHandlerRegistry } from '../../../shared/queues/job-handler.registry.js';
import { PRESENCE_RETENTION_DAYS, residenceDayDaysAgo } from '../domain/residence.js';
import { ACCOUNT_DELETED_EVENT, PRESENCE_CLEANUP_JOB } from './identity-events.js';
import { ManageAccountPrivacy } from './manage-account-privacy.js';
import { RESIDENCE_STORE, type ResidenceStore } from './residence-store.js';

const accountDeletedJob = z.object({
  agregadoId: z.uuid(),
  ocurridoEn: z.iso.datetime(),
});

@Injectable()
export class IdentityJobs implements OnModuleInit {
  constructor(
    private readonly registry: JobHandlerRegistry,
    private readonly privacy: ManageAccountPrivacy,
    @Inject(UNIT_OF_WORK) private readonly unitOfWork: UnitOfWork,
    @Inject(RESIDENCE_STORE) private readonly residence: ResidenceStore,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  onModuleInit(): void {
    this.registry.register(ACCOUNT_DELETED_EVENT, async (data) => {
      const event = accountDeletedJob.parse(data);
      await this.privacy.eraseDeletedAccount(event.agregadoId, new Date(event.ocurridoEn));
    });
    this.registry.register(PRESENCE_CLEANUP_JOB, async () => {
      await this.unitOfWork.run((tx) =>
        this.residence.expirePresences(
          tx,
          residenceDayDaysAgo(this.clock.now(), PRESENCE_RETENTION_DAYS),
        ),
      );
    });
  }
}
