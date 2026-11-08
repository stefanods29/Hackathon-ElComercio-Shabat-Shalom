import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import { newId } from '../../../shared/domain/ids.js';
import type { ReputationFacts, ReputationRepository } from '../application/ports.js';
import { countsForRanking, type Endorsement, type EndorsementData } from '../domain/endorsement.js';
import type { Review, ReviewProps } from '../domain/review.js';
import { REVIEW_WINDOW_MS } from '../domain/review-policy.js';

export class InMemoryReputationRepository implements ReputationRepository {
  readonly reviews = new Map<string, ReviewProps>();
  readonly endorsements = new Map<string, Endorsement>();
  private readonly signals = new Map<string, string>();

  async lockAuthor(_transaction: TransactionContext, _authorId: string): Promise<void> {}
  async lockService(_transaction: TransactionContext, _serviceId: string): Promise<void> {}

  async findReview(_transaction: TransactionContext, id: string): Promise<ReviewProps | null> {
    return structuredClone(this.reviews.get(id) ?? null);
  }

  async hasReview(
    _transaction: TransactionContext,
    serviceId: string,
    authorId: string,
  ): Promise<boolean> {
    return [...this.reviews.values()].some(
      (review) => review.serviceId === serviceId && review.authorId === authorId,
    );
  }

  async countReviewsSince(
    _transaction: TransactionContext,
    authorId: string,
    since: Date,
  ): Promise<{ count: number; oldest: Date | null }> {
    const reviews = [...this.reviews.values()].filter(
      (review) => review.authorId === authorId && review.createdAt.getTime() > since.getTime(),
    );
    const oldest = reviews.sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime())[0];
    return { count: reviews.length, oldest: oldest ? structuredClone(oldest.createdAt) : null };
  }

  async insertReview(
    transaction: TransactionContext,
    review: Review,
    deviceHash: string | null,
  ): Promise<boolean> {
    const props = review.snapshot();
    if (
      (await this.hasReview(transaction, props.serviceId, props.authorId)) ||
      this.reviews.has(props.id)
    )
      return false;
    this.reviews.set(props.id, props);
    if (deviceHash) this.signals.set(props.id, deviceHash);
    return true;
  }

  async findEndorsement(
    _transaction: TransactionContext,
    serviceId: string,
    neighborId: string,
  ): Promise<Endorsement | null> {
    return structuredClone(this.endorsements.get(`${serviceId}:${neighborId}`) ?? null);
  }

  async insertEndorsement(
    _transaction: TransactionContext,
    data: EndorsementData,
  ): Promise<Endorsement | null> {
    const key = `${data.serviceId}:${data.neighborId}`;
    if (this.endorsements.has(key)) return null;
    const row = { ...data, id: newId() };
    this.endorsements.set(key, structuredClone(row));
    return row;
  }

  async deleteEndorsement(
    _transaction: TransactionContext,
    serviceId: string,
    neighborId: string,
  ): Promise<boolean> {
    return this.endorsements.delete(`${serviceId}:${neighborId}`);
  }

  async aggregateFacts(
    _transaction: TransactionContext,
    serviceId: string,
    zoneId: string,
  ): Promise<ReputationFacts> {
    const reviews = [...this.reviews.values()].filter(
      (review) => review.serviceId === serviceId && review.state === 'publicada',
    );
    const endorsements = [...this.endorsements.values()].filter(
      (endorsement) => endorsement.serviceId === serviceId,
    );
    return {
      reviewCount: reviews.length,
      ratingSum: reviews.reduce((total, review) => total + review.rating, 0),
      endorsementCount: endorsements.length,
      zoneEndorsementCount: endorsements.filter(
        (endorsement) => countsForRanking(endorsement) && endorsement.neighborZoneId === zoneId,
      ).length,
    };
  }

  async countDeviceReviewsForPendingReview(
    _transaction: TransactionContext,
    reviewId: string,
  ): Promise<number> {
    const review = this.reviews.get(reviewId);
    const signal = this.signals.get(reviewId);
    if (!review || review.state !== 'en_revision' || !signal) return 0;
    const at = review.createdAt.getTime();
    return [...this.reviews.values()].filter((other) => {
      const time = other.createdAt.getTime();
      return (
        this.signals.get(other.id) === signal &&
        time > at - REVIEW_WINDOW_MS &&
        (time < at || (time === at && other.id <= reviewId))
      );
    }).length;
  }
}
