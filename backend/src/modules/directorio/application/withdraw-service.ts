import { Inject, Injectable } from '@nestjs/common';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { ResourceNotFound, VersionConflict } from '../../../shared/domain/errors.js';
import { DIRECTORY_REPOSITORY, type DirectoryActor, type DirectoryRepository } from './ports.js';

@Injectable()
export class WithdrawService {
  constructor(
    @Inject(UNIT_OF_WORK) private readonly unitOfWork: UnitOfWork,
    @Inject(DIRECTORY_REPOSITORY) private readonly directory: DirectoryRepository,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  async execute(id: string, actor: DirectoryActor): Promise<void> {
    await this.unitOfWork.run(async (transaction) => {
      await this.directory.lockProvider(transaction, actor.id);
      const service = await this.directory.findService(transaction, id);
      if (!service) throw new ResourceNotFound('el servicio', id);
      const previousVersion = service.version;
      if (!service.withdraw(actor.id, this.clock.now())) return;
      if (!(await this.directory.updateService(transaction, service, previousVersion))) {
        const latest = await this.directory.findService(transaction, id);
        if (latest?.snapshot().deletedAt) {
          latest.assertOwner(actor.id);
          return;
        }
        throw new VersionConflict(previousVersion, latest?.version ?? previousVersion + 1);
      }
    });
  }
}
