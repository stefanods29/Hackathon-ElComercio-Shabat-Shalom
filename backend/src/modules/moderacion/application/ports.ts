import type { TransactionContext } from '../../../shared/db/unit-of-work.js';

export interface ReviewCaseStore {
  openReviewPatternCase(
    transaction: TransactionContext,
    reviewId: string,
    now: Date,
  ): Promise<void>;
}

export const REVIEW_CASE_STORE = Symbol('REVIEW_CASE_STORE');
