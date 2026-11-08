import { Inject, Injectable } from '@nestjs/common';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import {
  BusinessRuleViolation,
  ResourceNotFound,
  VersionConflict,
} from '../../../shared/domain/errors.js';
import type { ServiceData, ServiceProps } from '../domain/service.js';
import { DIRECTORY_REPOSITORY, type DirectoryActor, type DirectoryRepository } from './ports.js';

@Injectable()
export class EditService {
  constructor(
    @Inject(UNIT_OF_WORK) private readonly unitOfWork: UnitOfWork,
    @Inject(DIRECTORY_REPOSITORY) private readonly directory: DirectoryRepository,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  async execute(
    id: string,
    seenVersion: number,
    data: ServiceData,
    actor: DirectoryActor,
  ): Promise<ServiceProps> {
    return this.unitOfWork.run(async (transaction) => {
      await this.directory.lockProvider(transaction, actor.id);
      const service = await this.directory.findService(transaction, id);
      if (!service) throw new ResourceNotFound('el servicio', id);
      const previousVersion = service.version;
      service.edit(actor.id, seenVersion, data, this.clock.now());
      if (!(await this.directory.categoryExists(transaction, data.categoryId))) {
        throw new BusinessRuleViolation(
          'categoria_invalida',
          'Elige una categoría del directorio.',
        );
      }
      if (!(await this.directory.updateService(transaction, service, previousVersion))) {
        const latest = await this.directory.findService(transaction, id);
        throw new VersionConflict(seenVersion, latest?.version ?? previousVersion + 1);
      }
      return service.snapshot();
    });
  }
}
