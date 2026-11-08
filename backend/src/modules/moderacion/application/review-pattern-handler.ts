import { Inject, Injectable, type OnModuleInit } from '@nestjs/common';
import { z } from 'zod';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { JobHandlerRegistry } from '../../../shared/queues/job-handler.registry.js';
import {
  REVIEW_CREATED_EVENT,
  REVIEW_RISK_READER,
  type ReviewRiskReader,
} from '../../reputacion/index.js';
import { isSuspiciousReviewBurst } from '../domain/review-pattern.js';
import { REVIEW_CASE_STORE, type ReviewCaseStore } from './ports.js';

const reviewEvent = z.object({ agregadoId: z.uuid() });

@Injectable()
export class ReviewPatternHandler implements OnModuleInit {
  constructor(
    private readonly registry: JobHandlerRegistry,
    @Inject(UNIT_OF_WORK) private readonly unitOfWork: UnitOfWork,
    @Inject(REVIEW_RISK_READER) private readonly risk: ReviewRiskReader,
    @Inject(REVIEW_CASE_STORE) private readonly cases: ReviewCaseStore,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  onModuleInit(): void {
    this.registry.register(REVIEW_CREATED_EVENT, (event) => this.handle(event));
  }

  async handle(event: unknown): Promise<void> {
    const { agregadoId: reviewId } = reviewEvent.parse(event);
    await this.unitOfWork.run(async (transaction) => {
      const count = await this.risk.countDeviceReviewsForPendingReview(transaction, reviewId);
      if (isSuspiciousReviewBurst(count)) {
        await this.cases.openReviewPatternCase(transaction, reviewId, this.clock.now());
      }
    });
  }
}
