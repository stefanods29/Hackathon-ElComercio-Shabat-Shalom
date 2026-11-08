import { Injectable } from '@nestjs/common';
import type { TransactionContext } from '../db/unit-of-work.js';

export const CONTENT_TYPES = ['publicacion', 'resena', 'servicio', 'foto', 'proveedor'] as const;
export type ContentType = (typeof CONTENT_TYPES)[number];

export const CONTENT_APPROVED = 'moderacion.contenido_aprobado';
export const CONTENT_HIDDEN = 'moderacion.contenido_ocultado';
export const CONTENT_RESTORED = 'moderacion.contenido_restaurado';
export type VisibilityEvent =
  typeof CONTENT_APPROVED | typeof CONTENT_HIDDEN | typeof CONTENT_RESTORED;

export interface ContentRef {
  readonly type: ContentType;
  readonly id: string;
}

export interface ContentForModeration {
  readonly ownerId: string;
  readonly text: readonly string[];
  readonly imageIds: readonly string[];
  readonly deviceReviewCount?: number;
}

export interface ContentModerationOwner {
  read(tx: TransactionContext, ref: ContentRef): Promise<ContentForModeration | null>;
  apply(
    tx: TransactionContext,
    ref: ContentRef,
    event: VisibilityEvent,
    reason: string,
    now: Date,
  ): Promise<void>;
}

/** Each owner supplies the read and write adapters for its own content. */
@Injectable()
export class ContentModerationRegistry {
  private readonly owners = new Map<ContentType, ContentModerationOwner>();

  register(type: ContentType, owner: ContentModerationOwner): void {
    if (this.owners.has(type)) throw new Error('Dueño de moderación duplicado: ' + type);
    this.owners.set(type, owner);
  }

  owner(type: ContentType): ContentModerationOwner {
    const owner = this.owners.get(type);
    if (!owner) throw new Error('Falta el dueño de moderación para: ' + type);
    return owner;
  }
}
