import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import type { Endorsement, EndorsementData } from '../domain/endorsement.js';
import type { Review, ReviewProps } from '../domain/review.js';

export interface ReputationActor {
  readonly id: string;
  readonly zoneId: string | null;
  readonly trustLevel: number;
  readonly sessionId?: string;
}

export interface OwnedReadyFile {
  readonly id: string;
  readonly purpose: 'resena' | 'servicio';
  readonly width: number;
  readonly height: number;
  readonly blurhash: string | null;
}

/** Same lookup as the public Media interface planned by C1. */
export interface ReviewPhotoReader {
  findOwnedReadyFile(fileId: string, ownerId: string): Promise<OwnedReadyFile | null>;
}

export const REVIEW_PHOTO_READER = Symbol('REVIEW_PHOTO_READER');

export interface ReputationFacts {
  readonly reviewCount: number;
  readonly ratingSum: number;
  readonly endorsementCount: number;
  readonly zoneEndorsementCount: number;
}

export interface ReviewRiskReader {
  countDeviceReviewsForPendingReview(
    transaction: TransactionContext,
    reviewId: string,
  ): Promise<number>;
}

export const REVIEW_RISK_READER = Symbol('REVIEW_RISK_READER');

export interface ReputationRepository extends ReviewRiskReader {
  lockAuthor(transaction: TransactionContext, authorId: string): Promise<void>;
  lockService(transaction: TransactionContext, serviceId: string): Promise<void>;
  findReview(transaction: TransactionContext, id: string): Promise<ReviewProps | null>;
  hasReview(transaction: TransactionContext, serviceId: string, authorId: string): Promise<boolean>;
  countReviewsSince(
    transaction: TransactionContext,
    authorId: string,
    since: Date,
  ): Promise<{ count: number; oldest: Date | null }>;
  insertReview(
    transaction: TransactionContext,
    review: Review,
    deviceHash: string | null,
  ): Promise<boolean>;
  findEndorsement(
    transaction: TransactionContext,
    serviceId: string,
    neighborId: string,
  ): Promise<Endorsement | null>;
  insertEndorsement(
    transaction: TransactionContext,
    data: EndorsementData,
  ): Promise<Endorsement | null>;
  deleteEndorsement(
    transaction: TransactionContext,
    serviceId: string,
    neighborId: string,
  ): Promise<boolean>;
  aggregateFacts(
    transaction: TransactionContext,
    serviceId: string,
    zoneId: string,
  ): Promise<ReputationFacts>;
}

export const REPUTATION_REPOSITORY = Symbol('REPUTATION_REPOSITORY');
