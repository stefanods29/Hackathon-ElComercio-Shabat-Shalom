import { Inject, Injectable } from '@nestjs/common';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import {
  BusinessRuleViolation,
  ResourceNotFound,
  ValidationError,
} from '../../../shared/domain/errors.js';
import { newId } from '../../../shared/domain/ids.js';
import { OUTBOX_WRITER, type OutboxWriter } from '../../../shared/outbox/outbox.js';
import { APP_CONFIG, type AppConfig } from '../../../shared/config/app-config.js';
import { DIRECTORY_SERVICE_READER, type DirectoryServiceReader } from '../../directorio/index.js';
import { REVIEWER_READER, type ReviewerReader } from '../../identidad/index.js';
import { Review, type ReviewPhoto, type ReviewProps } from '../domain/review.js';
import { assertAccountAge, assertReviewQuota, REVIEW_WINDOW_MS } from '../domain/review-policy.js';
import {
  REPUTATION_REPOSITORY,
  REVIEW_PHOTO_READER,
  type ReputationActor,
  type ReputationRepository,
  type ReviewPhotoReader,
} from './ports.js';
import { assertCanRate, reputationZone } from './reputation-access.js';

export interface WriteReviewCommand {
  readonly id: string;
  readonly serviceId: string;
  readonly rating: number;
  readonly comment: string | null;
  readonly fileIds: readonly string[];
}

export interface WriteReviewResult {
  readonly review: ReviewProps;
  readonly created: boolean;
}

@Injectable()
export class WriteReview {
  constructor(
    @Inject(UNIT_OF_WORK) private readonly unitOfWork: UnitOfWork,
    @Inject(REPUTATION_REPOSITORY) private readonly reviews: ReputationRepository,
    @Inject(DIRECTORY_SERVICE_READER) private readonly services: DirectoryServiceReader,
    @Inject(REVIEWER_READER) private readonly reviewers: ReviewerReader,
    @Inject(REVIEW_PHOTO_READER) private readonly files: ReviewPhotoReader,
    @Inject(OUTBOX_WRITER) private readonly outbox: OutboxWriter,
    @Inject(CLOCK) private readonly clock: Clock,
    @Inject(APP_CONFIG)
    private readonly config: Pick<
      AppConfig,
      'MIN_ACCOUNT_AGE_HOURS_TO_REVIEW' | 'MAX_REVIEWS_PER_DAY'
    >,
  ) {}

  async execute(command: WriteReviewCommand, actor: ReputationActor): Promise<WriteReviewResult> {
    const zoneId = reputationZone(actor);
    return this.unitOfWork.run(async (transaction) => {
      await this.reviews.lockAuthor(transaction, actor.id);
      const existing = await this.reviews.findReview(transaction, command.id);
      if (existing) return this.existing(existing, actor.id);
      const service = await this.services.findForReputation(transaction, command.serviceId);
      assertCanRate(service, command.serviceId, actor.id, zoneId);
      if (await this.reviews.hasReview(transaction, command.serviceId, actor.id))
        throw this.duplicate();
      const author = await this.reviewers.findReviewer(transaction, actor.id, actor.sessionId);
      if (!author) throw new ResourceNotFound('el vecino', actor.id);
      const now = this.clock.now();
      assertAccountAge(author.createdAt, now, this.config.MIN_ACCOUNT_AGE_HOURS_TO_REVIEW);
      const usage = await this.reviews.countReviewsSince(
        transaction,
        actor.id,
        new Date(now.getTime() - REVIEW_WINDOW_MS),
      );
      assertReviewQuota(usage, now, this.config.MAX_REVIEWS_PER_DAY);
      const photos = await this.loadPhotos(command.fileIds, actor.id);
      const review = Review.create(
        {
          id: command.id,
          serviceId: command.serviceId,
          authorId: actor.id,
          authorZoneId: zoneId,
          rating: command.rating,
          comment: command.comment,
          photos,
        },
        now,
      );
      if (!(await this.reviews.insertReview(transaction, review, author.deviceHash))) {
        const concurrent = await this.reviews.findReview(transaction, command.id);
        if (concurrent) return this.existing(concurrent, actor.id);
        throw this.duplicate();
      }
      await this.outbox.record(transaction, 'reputacion', review.pullEvents());
      return { review: review.snapshot(), created: true };
    });
  }

  private duplicate(): BusinessRuleViolation {
    return new BusinessRuleViolation('resena_duplicada', 'Ya reseñaste este servicio.', 'conflict');
  }

  private existing(review: ReviewProps, actorId: string): WriteReviewResult {
    if (review.authorId !== actorId) {
      throw new BusinessRuleViolation(
        'id_en_uso',
        'Ese id ya está en uso. Genera uno nuevo en el celular.',
        'conflict',
      );
    }
    return { review, created: false };
  }

  private async loadPhotos(fileIds: readonly string[], ownerId: string): Promise<ReviewPhoto[]> {
    const ids = fileIds.map((id) => id.toLowerCase());
    if (ids.length > 3 || new Set(ids).size !== ids.length) {
      throw new ValidationError([
        { field: 'fotos', message: 'Debe haber hasta tres archivos distintos.' },
      ]);
    }
    return Promise.all(
      ids.map(async (fileId, order) => {
        const file = await this.files.findOwnedReadyFile(fileId, ownerId);
        if (
          !file ||
          file.id !== fileId ||
          file.purpose !== 'resena' ||
          !Number.isInteger(file.width) ||
          file.width <= 0 ||
          !Number.isInteger(file.height) ||
          file.height <= 0
        ) {
          throw new BusinessRuleViolation(
            'archivo_no_valido',
            'La foto debe estar lista y pertenecer a tu cuenta.',
          );
        }
        return {
          id: newId(),
          fileId,
          order,
          width: file.width,
          height: file.height,
          blurhash: file.blurhash,
          hiddenAt: null,
        };
      }),
    );
  }
}
