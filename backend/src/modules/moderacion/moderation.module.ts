import { Module } from '@nestjs/common';
import { ReputationModule } from '../reputacion/index.js';
import { REVIEW_CASE_STORE } from './application/ports.js';
import { ReviewPatternHandler } from './application/review-pattern-handler.js';
import { KyselyReviewCaseStore } from './infrastructure/review-case.store.kysely.js';

@Module({
  imports: [ReputationModule],
  providers: [
    ReviewPatternHandler,
    { provide: REVIEW_CASE_STORE, useClass: KyselyReviewCaseStore },
  ],
})
export class ModerationModule {}
