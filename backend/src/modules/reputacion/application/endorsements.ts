import { Inject, Injectable } from '@nestjs/common';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { OUTBOX_WRITER, type OutboxWriter } from '../../../shared/outbox/outbox.js';
import { DIRECTORY_SERVICE_READER, type DirectoryServiceReader } from '../../directorio/index.js';
import type { Endorsement } from '../domain/endorsement.js';
import { REPUTATION_REPOSITORY, type ReputationActor, type ReputationRepository } from './ports.js';
import { assertCanRate, assertReputationLevel, reputationZone } from './reputation-access.js';
import { recalculationRequested } from './reputation-events.js';

@Injectable()
export class Endorsements {
  constructor(
    @Inject(UNIT_OF_WORK) private readonly unitOfWork: UnitOfWork,
    @Inject(REPUTATION_REPOSITORY) private readonly reputation: ReputationRepository,
    @Inject(DIRECTORY_SERVICE_READER) private readonly services: DirectoryServiceReader,
    @Inject(OUTBOX_WRITER) private readonly outbox: OutboxWriter,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  async give(serviceId: string, actor: ReputationActor): Promise<Endorsement> {
    const zoneId = reputationZone(actor);
    return this.unitOfWork.run(async (transaction) => {
      await this.reputation.lockService(transaction, serviceId);
      const service = await this.services.findForReputation(transaction, serviceId);
      assertCanRate(service, serviceId, actor.id, zoneId);
      const existing = await this.reputation.findEndorsement(transaction, serviceId, actor.id);
      if (existing) return existing;
      const now = this.clock.now();
      const created = await this.reputation.insertEndorsement(transaction, {
        serviceId,
        neighborId: actor.id,
        neighborZoneId: zoneId,
        trustLevelAtGiving: actor.trustLevel,
        createdAt: now,
      });
      if (created) {
        await this.outbox.record(transaction, 'reputacion', [
          recalculationRequested(serviceId, now),
        ]);
        return created;
      }
      const concurrent = await this.reputation.findEndorsement(transaction, serviceId, actor.id);
      if (!concurrent) throw new Error('No se pudo recuperar el Visto Bueno concurrente.');
      return concurrent;
    });
  }

  async withdraw(serviceId: string, actor: ReputationActor): Promise<void> {
    assertReputationLevel(actor);
    await this.unitOfWork.run(async (transaction) => {
      await this.reputation.lockService(transaction, serviceId);
      if (await this.reputation.deleteEndorsement(transaction, serviceId, actor.id)) {
        await this.outbox.record(transaction, 'reputacion', [
          recalculationRequested(serviceId, this.clock.now()),
        ]);
      }
    });
  }
}
