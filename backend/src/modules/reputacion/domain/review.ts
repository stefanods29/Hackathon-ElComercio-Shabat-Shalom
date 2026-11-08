import type { DomainEvent } from '../../../shared/domain/domain-event.js';
import { ValidationError } from '../../../shared/domain/errors.js';
import { isUuidV7 } from '../../../shared/domain/ids.js';

export const REVIEW_CREATED_EVENT = 'reputacion.resena_creada';
export const REVIEW_STATES = ['en_revision', 'publicada', 'oculta'] as const;
export type ReviewState = (typeof REVIEW_STATES)[number];

export interface ReviewPhoto {
  readonly id: string;
  readonly fileId: string;
  readonly order: number;
  readonly width: number;
  readonly height: number;
  readonly blurhash: string | null;
  readonly hiddenAt: Date | null;
}

export interface NewReview {
  readonly id: string;
  readonly serviceId: string;
  readonly authorId: string;
  readonly authorZoneId: string;
  readonly rating: number;
  readonly comment: string | null;
  readonly photos: readonly ReviewPhoto[];
}

export interface ReviewProps extends NewReview {
  readonly state: ReviewState;
  readonly stateReason: string | null;
  readonly createdAt: Date;
  readonly updatedAt: Date;
  readonly publishedAt: Date | null;
}

export class Review {
  private events: DomainEvent[] = [];

  private constructor(private readonly props: ReviewProps) {}

  static create(data: NewReview, now: Date): Review {
    if (!isUuidV7(data.id))
      throw new ValidationError([{ field: 'id', message: 'Debe ser UUIDv7.' }]);
    if (!Number.isInteger(data.rating) || data.rating < 1 || data.rating > 5) {
      throw new ValidationError([
        { field: 'calificacion', message: 'Debe ser un entero de 1 a 5.' },
      ]);
    }
    const comment = data.comment?.trim() || null;
    if (comment && comment.length > 2000) {
      throw new ValidationError([{ field: 'comentario', message: 'Máximo 2000 caracteres.' }]);
    }
    if (
      data.photos.length > 3 ||
      new Set(data.photos.map((photo) => photo.fileId)).size !== data.photos.length
    ) {
      throw new ValidationError([
        { field: 'fotos', message: 'Debe haber hasta tres archivos distintos.' },
      ]);
    }
    const review = new Review({
      ...data,
      comment,
      photos: structuredClone(data.photos),
      state: 'en_revision',
      stateReason: null,
      createdAt: now,
      updatedAt: now,
      publishedAt: null,
    });
    review.events.push({
      type: REVIEW_CREATED_EVENT,
      aggregateId: data.id,
      occurredAt: now,
      payload: { servicioId: data.serviceId, autorId: data.authorId },
    });
    return review;
  }

  static restore(props: ReviewProps): Review {
    return new Review(structuredClone(props));
  }

  snapshot(): ReviewProps {
    return structuredClone(this.props);
  }

  pullEvents(): DomainEvent[] {
    const pending = this.events;
    this.events = [];
    return pending;
  }
}
