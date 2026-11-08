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
import { DIRECTORY_REPOSITORY, type DirectoryRepository } from '../application/ports.js';
import type { DirectoryTables } from './tables.js';

@Injectable()
export class DirectoryModeration implements OnModuleInit, ContentModerationOwner {
  constructor(
    private readonly registry: ContentModerationRegistry,
    @Inject(DIRECTORY_REPOSITORY) private readonly directory: DirectoryRepository,
  ) {}

  onModuleInit(): void {
    this.registry.register('proveedor', this);
    this.registry.register('servicio', this);
  }

  async read(tx: TransactionContext, ref: ContentRef) {
    const db = asKysely<DirectoryTables>(tx);
    if (ref.type === 'proveedor') {
      const provider = await db
        .selectFrom('directorio.proveedores')
        .select(['id', 'nombre_publico', 'descripcion'])
        .where('id', '=', ref.id)
        .where('eliminado_en', 'is', null)
        .executeTakeFirst();
      return provider
        ? {
            ownerId: provider.id,
            text: [provider.nombre_publico, provider.descripcion ?? ''],
            imageIds: [],
          }
        : null;
    }
    const service = await db
      .selectFrom('directorio.servicios')
      .select(['proveedor_id', 'titulo', 'descripcion', 'atributos'])
      .where('id', '=', ref.id)
      .where('eliminado_en', 'is', null)
      .executeTakeFirst();
    return service
      ? {
          ownerId: service.proveedor_id,
          text: [service.titulo, service.descripcion ?? '', JSON.stringify(service.atributos)],
          imageIds: [],
        }
      : null;
  }

  async apply(
    tx: TransactionContext,
    ref: ContentRef,
    event: VisibilityEvent,
    _reason: string,
    now: Date,
  ): Promise<void> {
    const db = asKysely<DirectoryTables>(tx);
    const hiddenAt = event === CONTENT_HIDDEN ? now : null;
    if (ref.type === 'proveedor') {
      await this.directory.lockProvider(tx, ref.id);
      const provider = await db
        .updateTable('directorio.proveedores')
        .set({ oculto_en: hiddenAt, actualizado_en: sql<Date>`greatest(actualizado_en, ${now})` })
        .where('id', '=', ref.id)
        .where('eliminado_en', 'is', null)
        .returning('id')
        .executeTakeFirst();
      if (!provider) return;
      // PowerSync filters services by their own effective flag, even when the provider is the subject.
      await db
        .updateTable('directorio.servicios')
        .set({
          oculto_en: sql<Date | null>`coalesce(oculto_individual_en, ${hiddenAt}::timestamptz)`,
          actualizado_en: sql<Date>`greatest(actualizado_en, ${now})`,
        })
        .where('proveedor_id', '=', ref.id)
        .where('eliminado_en', 'is', null)
        .execute();
      return;
    }

    const service = await db
      .selectFrom('directorio.servicios')
      .select('proveedor_id')
      .where('id', '=', ref.id)
      .executeTakeFirst();
    if (!service) return;
    await this.directory.lockProvider(tx, service.proveedor_id);
    const provider = await db
      .selectFrom('directorio.proveedores')
      .select('oculto_en')
      .where('id', '=', service.proveedor_id)
      .executeTakeFirst();
    await db
      .updateTable('directorio.servicios')
      .set({
        oculto_individual_en: hiddenAt,
        oculto_en: hiddenAt ?? provider?.oculto_en ?? null,
        actualizado_en: sql<Date>`greatest(actualizado_en, ${now})`,
      })
      .where('id', '=', ref.id)
      .where('eliminado_en', 'is', null)
      .execute();
  }
}
