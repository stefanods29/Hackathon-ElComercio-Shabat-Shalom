import { Inject, Injectable } from '@nestjs/common';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import type { ContentRef, VisibilityEvent } from '../../../shared/moderation/content-moderation.js';
import { OUTBOX_WRITER, type OutboxWriter } from '../../../shared/outbox/outbox.js';
import { MODERATION_STORE, type ModerationStore } from './ports.js';

export const MODERATION_MODULE = 'moderacion';
export const REPORT_CREATED = 'moderacion.denuncia_registrada';

@Injectable()
export class ModerationEvents {
  constructor(
    @Inject(MODERATION_STORE) private readonly store: ModerationStore,
    @Inject(OUTBOX_WRITER) private readonly outbox: OutboxWriter,
  ) {}

  async reportCreated(tx: TransactionContext, id: string, now: Date): Promise<void> {
    await this.outbox.record(tx, MODERATION_MODULE, [
      {
        type: REPORT_CREATED,
        aggregateId: id,
        occurredAt: now,
        payload: {},
      },
    ]);
  }

  /** The caller holds the lock for this content. The envelope orders decisions even with a fixed clock. */
  async visibility(
    tx: TransactionContext,
    ref: ContentRef,
    event: VisibilityEvent,
    reason: string,
    now: Date,
  ): Promise<void> {
    const previous = await this.store.visibility(tx, ref);
    const occurredAt = previous && previous.at >= now ? new Date(previous.at.getTime() + 1) : now;
    await this.store.scheduleVisibility(tx, ref, event, occurredAt);
    await this.outbox.record(tx, MODERATION_MODULE, [
      {
        type: event,
        aggregateId: ref.id,
        occurredAt,
        payload: { tipoContenido: ref.type, contenidoId: ref.id, motivo: reason },
      },
    ]);
  }
}
