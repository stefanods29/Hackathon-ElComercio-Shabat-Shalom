import { Inject, Injectable, type OnModuleInit } from '@nestjs/common';
import { z } from 'zod';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { JobHandlerRegistry } from '../../../shared/queues/job-handler.registry.js';
import { DIRECTORY_REPOSITORY, type DirectoryRepository } from './ports.js';

export const ZONE_CHANGED_EVENT = 'identidad.zona_cambiada';

const eventSchema = z.object({
  agregadoId: z.uuid(),
  carga: z.object({ zonaAnteriorId: z.uuid() }),
});

@Injectable()
export class ZoneChangedHandler implements OnModuleInit {
  constructor(
    private readonly registry: JobHandlerRegistry,
    @Inject(UNIT_OF_WORK) private readonly unitOfWork: UnitOfWork,
    @Inject(DIRECTORY_REPOSITORY) private readonly directory: DirectoryRepository,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  onModuleInit(): void {
    this.registry.register(ZONE_CHANGED_EVENT, (event) => this.handle(event));
  }

  async handle(data: unknown): Promise<void> {
    const event = eventSchema.parse(data);
    await this.unitOfWork.run(async (transaction) => {
      await this.directory.lockProvider(transaction, event.agregadoId);
      await this.directory.withdrawInZone(
        transaction,
        event.agregadoId,
        event.carga.zonaAnteriorId,
        this.clock.now(),
      );
    });
  }
}
