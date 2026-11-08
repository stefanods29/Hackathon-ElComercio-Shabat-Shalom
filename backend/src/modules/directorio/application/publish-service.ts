import { Inject, Injectable } from '@nestjs/common';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { BusinessRuleViolation, ResourceNotFound } from '../../../shared/domain/errors.js';
import { OUTBOX_WRITER, type OutboxWriter } from '../../../shared/outbox/outbox.js';
import { Service, type ServiceData, type ServiceProps } from '../domain/service.js';
import { requireProviderZone } from './authorization.js';
import { DIRECTORY_REPOSITORY, type DirectoryActor, type DirectoryRepository } from './ports.js';

export interface PublishServiceResult {
  readonly service: ServiceProps;
  readonly created: boolean;
}

@Injectable()
export class PublishService {
  constructor(
    @Inject(UNIT_OF_WORK) private readonly unitOfWork: UnitOfWork,
    @Inject(DIRECTORY_REPOSITORY) private readonly directory: DirectoryRepository,
    @Inject(OUTBOX_WRITER) private readonly outbox: OutboxWriter,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  async execute(
    command: ServiceData & { readonly id: string },
    actor: DirectoryActor,
  ): Promise<PublishServiceResult> {
    const zoneId = requireProviderZone(actor);
    return this.unitOfWork.run(async (transaction) => {
      await this.directory.lockProvider(transaction, actor.id);
      const existing = await this.directory.findService(transaction, command.id);
      if (existing) return this.existingResult(existing, actor.id);
      const provider = await this.directory.findProvider(transaction, actor.id);
      const profile = provider?.snapshot();
      if (!profile || profile.deletedAt || profile.hiddenAt || profile.zoneId !== zoneId) {
        throw new ResourceNotFound('el proveedor de tu zona', actor.id);
      }
      if (!(await this.directory.categoryExists(transaction, command.categoryId))) {
        throw new BusinessRuleViolation(
          'categoria_invalida',
          'Elige una categoría del directorio.',
        );
      }
      const service = Service.create(
        { ...command, providerId: actor.id, zoneId },
        this.clock.now(),
      );
      if (await this.directory.insertService(transaction, service)) {
        await this.outbox.record(transaction, 'directorio', service.pullEvents());
        return { service: service.snapshot(), created: true };
      }
      const concurrent = await this.directory.findService(transaction, command.id);
      if (!concurrent) throw new ResourceNotFound('el servicio', command.id);
      return this.existingResult(concurrent, actor.id);
    });
  }

  private existingResult(service: Service, providerId: string): PublishServiceResult {
    if (service.snapshot().providerId !== providerId) {
      throw new BusinessRuleViolation(
        'id_en_uso',
        'Ese id ya está en uso. Genera uno nuevo en el celular.',
        'conflict',
      );
    }
    return { service: service.snapshot(), created: false };
  }
}
