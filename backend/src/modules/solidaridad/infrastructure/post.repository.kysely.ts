import { Injectable } from '@nestjs/common';
import { type Selectable, sql } from 'kysely';
import { asKysely } from '../../../shared/db/unit-of-work.kysely.js';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import type { PostRepository } from '../application/ports.js';
import { Post } from '../domain/post.js';
import type { PostsTable, SolidarityTables } from './tables.js';

function toPost(row: Selectable<PostsTable>): Post {
  return Post.restore({
    id: row.id,
    authorId: row.autor_id,
    zoneId: row.zona_id,
    type: row.tipo,
    category: row.categoria,
    title: row.titulo,
    description: row.descripcion,
    location: row.lat !== null && row.lng !== null ? { lat: row.lat, lng: row.lng } : null,
    status: row.estado,
    takenById: row.tomada_por_id,
    version: row.version,
    expiresAt: row.vence_en,
    createdAt: row.creado_en,
    updatedAt: row.actualizado_en,
  });
}

const COLUMNS = [
  'id',
  'autor_id',
  'zona_id',
  'tipo',
  'categoria',
  'titulo',
  'descripcion',
  'lat',
  'lng',
  'estado',
  'tomada_por_id',
  'version',
  'vence_en',
  'creado_en',
  'actualizado_en',
  'eliminado_en',
] as const;

@Injectable()
export class KyselyPostRepository implements PostRepository {
  async insertIfAbsent(transaction: TransactionContext, post: Post): Promise<boolean> {
    const p = post.snapshot();
    const inserted = await asKysely<SolidarityTables>(transaction)
      .insertInto('solidaridad.publicaciones')
      .values({
        id: p.id,
        autor_id: p.authorId,
        zona_id: p.zoneId,
        tipo: p.type,
        categoria: p.category,
        titulo: p.title,
        descripcion: p.description,
        lat: p.location?.lat ?? null,
        lng: p.location?.lng ?? null,
        ubicacion: p.location
          ? sql`ST_SetSRID(ST_MakePoint(${p.location.lng}, ${p.location.lat}), 4326)::geography`
          : null,
        estado: p.status,
        tomada_por_id: p.takenById,
        version: p.version,
        vence_en: p.expiresAt,
        creado_en: p.createdAt,
        actualizado_en: p.updatedAt,
      })
      .onConflict((conflict) => conflict.column('id').doNothing())
      .returning('id')
      .executeTakeFirst();
    return inserted !== undefined;
  }

  async findById(transaction: TransactionContext, id: string): Promise<Post | null> {
    const row = await asKysely<SolidarityTables>(transaction)
      .selectFrom('solidaridad.publicaciones')
      .select(COLUMNS)
      .where('id', '=', id)
      .where('eliminado_en', 'is', null)
      .executeTakeFirst();
    return row ? toPost({ ...row, ubicacion: null }) : null;
  }

  async updateIfVersion(
    transaction: TransactionContext,
    post: Post,
    previousVersion: number,
  ): Promise<boolean> {
    const p = post.snapshot();
    const result = await asKysely<SolidarityTables>(transaction)
      .updateTable('solidaridad.publicaciones')
      .set({
        estado: p.status,
        tomada_por_id: p.takenById,
        version: p.version,
        actualizado_en: p.updatedAt,
      })
      .where('id', '=', p.id)
      .where('version', '=', previousVersion)
      .executeTakeFirst();
    return Number(result.numUpdatedRows) === 1;
  }
}
