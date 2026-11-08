import { Inject, Injectable, type OnModuleInit } from '@nestjs/common';
import { z } from 'zod';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { JobHandlerRegistry } from '../../../shared/queues/job-handler.registry.js';
import { averageRating, bayesianScore } from '../domain/reputation-ranking.js';
import { DIRECTORY_RANKING_STORE, type DirectoryRankingStore } from './reputation-ports.js';

const count = z.number().int().min(0).max(2147483647);
const envelope = z
  .object({
    eventoId: z.uuid(),
    agregadoId: z.uuid(),
    ocurridoEn: z.iso.datetime({ offset: true }),
    carga: z.strictObject({
      servicioId: z.uuid(),
      totalResenas: count,
      sumaCalificaciones: count,
      totalVistosBuenos: count,
      vistosBuenosDeLaZona: count,
    }),
  })
  .refine(
    ({ agregadoId, carga }) =>
      agregadoId === carga.servicioId &&
      carga.sumaCalificaciones >= carga.totalResenas &&
      carga.sumaCalificaciones <= 5 * carga.totalResenas &&
      carga.vistosBuenosDeLaZona <= carga.totalVistosBuenos,
  );

@Injectable()
export class ReputationAggregatesHandler implements OnModuleInit {
  constructor(
    private readonly registry: JobHandlerRegistry,
    @Inject(UNIT_OF_WORK) private readonly unitOfWork: UnitOfWork,
    @Inject(DIRECTORY_RANKING_STORE) private readonly store: DirectoryRankingStore,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  onModuleInit(): void {
    this.registry.register('reputacion.agregados_recalculados', (job) => this.handle(job));
  }

  async handle(job: unknown): Promise<void> {
    const event = envelope.parse(job);
    await this.unitOfWork.run(async (transaction) => {
      const now = this.clock.now();
      const category = await this.store.applyFacts(
        transaction,
        event.carga,
        {
          eventId: event.eventoId,
          occurredAt: event.ocurridoEn,
        },
        now,
      );
      if (!category) return;
      const services = await this.store.categoryFacts(transaction, category);
      const totals = services.reduce(
        (sum, service) => ({
          reviews: sum.reviews + service.reviewCount,
          ratings: sum.ratings + service.ratingSum,
        }),
        { reviews: 0, ratings: 0 },
      );
      const mean = averageRating(totals.ratings, totals.reviews);
      await this.store.saveScores(
        transaction,
        category,
        services.map((service) => ({
          id: service.id,
          score: bayesianScore(service.ratingSum, service.reviewCount, mean),
        })),
        now,
      );
    });
  }
}
