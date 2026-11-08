import { Inject, Injectable, type OnModuleInit } from '@nestjs/common';
import { sql } from 'kysely';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import { asKysely } from '../../../shared/db/unit-of-work.kysely.js';
import {
  CONTENT_HIDDEN,
  ContentModerationRegistry,
  type ContentModerationOwner,
  type ContentRef,
  type VisibilityEvent,
} from '../../../shared/moderation/content-moderation.js';
import type { DomainEvent } from '../../../shared/domain/domain-event.js';
import { OUTBOX_WRITER, type OutboxWriter } from '../../../shared/outbox/outbox.js';
import { REPUTATION_REPOSITORY, type ReputationRepository } from '../application/ports.js';
import {
  recalculationRequested,
  REVIEW_PUBLISHED_EVENT,
} from '../application/reputation-events.js';
import type { ReputationTables } from './tables.js';

@Injectable()
export class ReputationModeration implements OnModuleInit, ContentModerationOwner {
  constructor(
    private readonly registry: ContentModerationRegistry,
    @Inject(REPUTATION_REPOSITORY) private readonly reviews: ReputationRepository,
    @Inject(OUTBOX_WRITER) private readonly outbox: OutboxWriter,
  ) {}

  onModuleInit(): void {
    this.registry.register('resena', this);
    this.registry.register('foto', this);
  }

  async read(tx: TransactionContext, ref: ContentRef) {
    const db = asKysely<ReputationTables>(tx);
    if (ref.type === 'foto') {
      const photo = await db
        .selectFrom('reputacion.resena_fotos as foto')
        .innerJoin('reputacion.resenas as resena', 'resena.id', 'foto.resena_id')
        .select(['resena.autor_id', 'foto.archivo_id'])
        .where('foto.id', '=', ref.id)
        .executeTakeFirst();
      return photo ? { ownerId: photo.autor_id, text: [], imageIds: [photo.archivo_id] } : null;
    }
    const review = await this.reviews.findReview(tx, ref.id);
    return review
      ? {
          ownerId: review.authorId,
          text: [review.comment ?? ''],
          imageIds: review.photos.map((photo) => photo.fileId),
          deviceReviewCount: await this.reviews.countDeviceReviewsForPendingReview(tx, ref.id),
        }
      : null;
  }

  async apply(
    tx: TransactionContext,
    ref: ContentRef,
    event: VisibilityEvent,
    reason: string,
    now: Date,
  ): Promise<void> {
    const db = asKysely<ReputationTables>(tx);
    const hidden = event === CONTENT_HIDDEN;
    if (ref.type === 'foto') {
      await db
        .updateTable('reputacion.resena_fotos')
        .set({ oculta_en: hidden ? now : null })
        .where('id', '=', ref.id)
        .where('oculta_en', hidden ? 'is' : 'is not', null)
        .execute();
      return;
    }
    const review = await db
      .selectFrom('reputacion.resenas')
      .select(['autor_id', 'servicio_id', 'estado', 'motivo_estado', 'publicada_en'])
      .where('id', '=', ref.id)
      .forUpdate()
      .executeTakeFirst();
    if (!review) return;
    const state = hidden ? 'oculta' : 'publicada';
    const publicReason = hidden ? reason : null;
    if (review.estado === state && review.motivo_estado === publicReason) return;
    await db
      .updateTable('reputacion.resenas')
      .set({
        estado: state,
        motivo_estado: publicReason,
        publicada_en: hidden ? review.publicada_en : (review.publicada_en ?? now),
        actualizado_en: sql<Date>`greatest(actualizado_en, ${now})`,
      })
      .where('id', '=', ref.id)
      .execute();
    const events: DomainEvent[] = [];
    if (state !== review.estado && (state === 'publicada' || review.estado === 'publicada')) {
      events.push(recalculationRequested(review.servicio_id, now));
    }
    if (!hidden && !review.publicada_en) {
      events.push({
        type: REVIEW_PUBLISHED_EVENT,
        aggregateId: ref.id,
        occurredAt: now,
        payload: { resenaId: ref.id, servicioId: review.servicio_id, autorId: review.autor_id },
      });
    }
    if (events.length) await this.outbox.record(tx, 'reputacion', events);
  }
}
