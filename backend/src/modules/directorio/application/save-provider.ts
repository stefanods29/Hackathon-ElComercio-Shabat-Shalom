import { Inject, Injectable } from '@nestjs/common';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { OUTBOX_WRITER, type OutboxWriter } from '../../../shared/outbox/outbox.js';
import { ResourceNotFound } from '../../../shared/domain/errors.js';
import {
  ProviderProfile,
  type ProviderData,
  type ProviderProps,
} from '../domain/provider-profile.js';
import { requireProviderZone } from './authorization.js';
import { DIRECTORY_REPOSITORY, type DirectoryActor, type DirectoryRepository } from './ports.js';

@Injectable()
export class SaveProvider {
  constructor(
    @Inject(UNIT_OF_WORK) private readonly unitOfWork: UnitOfWork,
    @Inject(DIRECTORY_REPOSITORY) private readonly directory: DirectoryRepository,
    @Inject(CLOCK) private readonly clock: Clock,
    @Inject(OUTBOX_WRITER) private readonly outbox: OutboxWriter,
  ) {}

  async execute(data: ProviderData, actor: DirectoryActor): Promise<ProviderProps> {
    const zoneId = requireProviderZone(actor);
    return this.unitOfWork.run(async (transaction) => {
      await this.directory.lockProvider(transaction, actor.id);
      let provider = await this.directory.findProvider(transaction, actor.id);
      const now = this.clock.now();
      const created = provider === null;
      if (provider) {
        if (provider.snapshot().deletedAt || provider.snapshot().hiddenAt) {
          throw new ResourceNotFound('el proveedor', actor.id);
        }
        provider.update(actor.id, zoneId, data, now);
      } else {
        provider = ProviderProfile.create(actor.id, zoneId, data, now);
      }
      await this.directory.saveProvider(transaction, provider);
      if (created) {
        await this.outbox.record(transaction, 'directorio', [
          {
            type: 'directorio.proveedor_publicado',
            aggregateId: actor.id,
            occurredAt: now,
            payload: { zonaId: zoneId },
          },
        ]);
      }
      return provider.snapshot();
    });
  }
}
