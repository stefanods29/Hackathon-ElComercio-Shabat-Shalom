import { Inject, Injectable } from '@nestjs/common';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import type { ContentForModeration } from '../../../shared/moderation/content-moderation.js';
import { PublicationPolicy } from '../../../shared/moderation/publication-policy.js';
import { AUTHOR_TRUST, type AuthorTrust } from '../../identidad/index.js';
import { isSuspiciousReviewBurst } from '../domain/review-pattern.js';
import { hasBlockedText, type ScreeningFlag } from '../domain/screening.js';
import { IMAGE_MODERATION, type ImageModeration } from './ports.js';

@Injectable()
export class ScreenContent {
  constructor(
    @Inject(IMAGE_MODERATION) private readonly images: ImageModeration,
    @Inject(AUTHOR_TRUST) private readonly authors: AuthorTrust,
    private readonly publication: PublicationPolicy,
  ) {}

  async evaluate(
    tx: TransactionContext,
    content: ContentForModeration,
    now: Date,
    details?: string,
    minimumTrust = 2,
  ): Promise<ScreeningFlag | null> {
    const blockedText = hasBlockedText(details ? [...content.text, details] : content.text);
    const images = await Promise.all(
      [...new Set(content.imageIds)].map((file) => this.images.inspect(file)),
    );
    const trust = await this.authors.trustLevel(tx, content.ownerId);
    const suspended = await this.publication.isSuspended(content.ownerId, now, tx);

    if (blockedText) return 'texto_bloqueado';
    if (images.includes('dudosa')) return 'imagen_dudosa';
    if (images.includes('sin_verificar')) return 'imagen_sin_verificar';
    if (isSuspiciousReviewBurst(content.deviceReviewCount ?? 0)) return 'patron_de_resenas';
    if (suspended) return 'autor_suspendido';
    if (trust === null || trust < minimumTrust) return 'autor_no_verificado';
    return null;
  }
}
