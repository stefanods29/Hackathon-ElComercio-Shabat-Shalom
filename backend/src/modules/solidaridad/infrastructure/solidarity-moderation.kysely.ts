import { Injectable, type OnModuleInit } from '@nestjs/common';
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
import type { SolidarityTables } from './tables.js';

@Injectable()
export class SolidarityModeration implements OnModuleInit, ContentModerationOwner {
  constructor(private readonly registry: ContentModerationRegistry) {}

  onModuleInit(): void {
    this.registry.register('publicacion', this);
  }

  async read(tx: TransactionContext, { id }: ContentRef) {
    const post = await asKysely<SolidarityTables>(tx)
      .selectFrom('solidaridad.publicaciones')
      .select(['autor_id', 'categoria', 'titulo', 'descripcion'])
      .where('id', '=', id)
      .where('eliminado_en', 'is', null)
      .executeTakeFirst();
    return post
      ? {
          ownerId: post.autor_id,
          text: [post.categoria, post.titulo, post.descripcion ?? ''],
          imageIds: [],
        }
      : null;
  }

  async apply(
    tx: TransactionContext,
    { id }: ContentRef,
    event: VisibilityEvent,
    _reason: string,
    now: Date,
  ): Promise<void> {
    const hide = event === CONTENT_HIDDEN;
    await asKysely<SolidarityTables>(tx)
      .updateTable('solidaridad.publicaciones')
      .set((eb) => ({
        oculta_en: hide ? now : null,
        actualizado_en: sql<Date>`greatest(actualizado_en, ${now})`,
        version: eb('version', '+', 1),
      }))
      .where('id', '=', id)
      .where('eliminado_en', 'is', null)
      .where('oculta_en', hide ? 'is' : 'is not', null)
      .execute();
  }
}
