import { Inject, Injectable, type OnModuleInit } from '@nestjs/common';
import { z } from 'zod';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { OUTBOX_WRITER, type OutboxWriter } from '../../../shared/outbox/outbox.js';
import { JobHandlerRegistry } from '../../../shared/queues/job-handler.registry.js';
import { DIRECTORY_SERVICE_READER, type DirectoryServiceReader } from '../../directorio/index.js';
import { REPUTATION_REPOSITORY, type ReputationRepository } from './ports.js';
import { REPUTATION_AGGREGATES_EVENT, REPUTATION_RECALCULATION_JOB } from './reputation-events.js';

const requestSchema = z
  .object({
    agregadoId: z.uuid(),
    carga: z.object({ servicioId: z.uuid() }),
  })
  .refine((event) => event.agregadoId === event.carga.servicioId);

@Injectable()
export class RecalculateReputation implements OnModuleInit {
  constructor(
    private readonly registry: JobHandlerRegistry,
    @Inject(UNIT_OF_WORK) private readonly unitOfWork: UnitOfWork,
    @Inject(REPUTATION_REPOSITORY) private readonly reputation: ReputationRepository,
    @Inject(DIRECTORY_SERVICE_READER) private readonly services: DirectoryServiceReader,
    @Inject(OUTBOX_WRITER) private readonly outbox: OutboxWriter,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  onModuleInit(): void {
    this.registry.register(REPUTATION_RECALCULATION_JOB, (event) => this.handle(event));
  }

  async handle(event: unknown): Promise<void> {
    const {
      carga: { servicioId },
    } = requestSchema.parse(event);
    await this.unitOfWork.run(async (transaction) => {
      await this.reputation.lockService(transaction, servicioId);
      const service = await this.services.findForReputation(transaction, servicioId);
      if (!service) return;
      const facts = await this.reputation.aggregateFacts(transaction, servicioId, service.zoneId);
      await this.outbox.record(transaction, 'reputacion', [
        {
          type: REPUTATION_AGGREGATES_EVENT,
          aggregateId: servicioId,
          occurredAt: this.clock.now(),
          payload: {
            servicioId,
            totalResenas: facts.reviewCount,
            sumaCalificaciones: facts.ratingSum,
            totalVistosBuenos: facts.endorsementCount,
            vistosBuenosDeLaZona: facts.zoneEndorsementCount,
          },
        },
      ]);
    });
  }
}
