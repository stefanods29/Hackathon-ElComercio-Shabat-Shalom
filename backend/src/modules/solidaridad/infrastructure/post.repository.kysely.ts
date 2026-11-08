import { Inject, Injectable } from '@nestjs/common';
import { PublicationPolicy } from '../../moderacion/index.js';
import { AccountAccess } from '../../../shared/auth/account-access.js';
import { type Kysely, type Selectable, sql } from 'kysely';
import { KYSELY } from '../../../shared/db/connection.js';
import { asKysely } from '../../../shared/db/unit-of-work.kysely.js';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import type {
  PostRepository,
  NearbyPostReader,
  NearbyQuery,
  NearbyPage,
} from '../application/ports.js';
import { invalidNearbyCursor } from '../application/nearby-cursor.js';
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
  'oculta_en',
] as const;

@Injectable()
export class KyselyPostRepository implements PostRepository, NearbyPostReader {
  constructor(
    @Inject(KYSELY) private readonly db: Kysely<SolidarityTables>,
    private readonly accounts: AccountAccess,
    private readonly publication: PublicationPolicy,
  ) {}

  async lockAuthor(transaction: TransactionContext, authorId: string): Promise<void> {
    await sql`SELECT pg_advisory_xact_lock(hashtextextended(${`solidaridad:publicaciones:autor:${authorId}`}, 0))`.execute(
      asKysely(transaction),
    );
  }

  async countByAuthorSince(
    transaction: TransactionContext,
    authorId: string,
    since: Date,
  ): Promise<{ count: number; oldest: Date | null }> {
    const { rows } = await sql<{ count: number; oldest: Date | null }>`
      SELECT count(*)::int AS count, min(creado_en) AS oldest FROM solidaridad.publicaciones
      WHERE autor_id = ${authorId} AND creado_en > ${since}
    `.execute(asKysely(transaction));
    return rows[0]!;
  }

  async findNearby(query: NearbyQuery): Promise<NearbyPage> {
    const point = sql`ST_SetSRID(ST_MakePoint(${query.location.lng}, ${query.location.lat}), 4326)::geography`;
    const rounded = (distance: number) => Math.round(distance / 50) * 50;
    let cursorDistance: number | null = null;
    if (query.cursor) {
      // Reconstruct the exact sorting key server-side; the cursor only exposes a 50 m bucket.
      // Keep the anchor usable after cancellation/expiry/soft deletion between pages.
      const anchor = await sql<{
        distance: number;
      }>`SELECT ST_Distance(ubicacion, ${point}) AS distance
        FROM solidaridad.publicaciones WHERE id = ${query.cursor.id} AND zona_id = ${query.zoneId} AND oculta_en IS NULL
          AND ubicacion IS NOT NULL AND ST_DWithin(ubicacion, ${point}, ${query.radius})`.execute(
        this.db,
      );
      if (!anchor.rows[0] || rounded(anchor.rows[0].distance) !== query.cursor.d)
        throw invalidNearbyCursor();
      cursorDistance = anchor.rows[0].distance;
    }
    const { rows } = await sql<Selectable<PostsTable> & { distancia: number }>`
      WITH cercanas AS (
        SELECT p.*, ST_Distance(p.ubicacion, ${point}) AS distancia
        FROM solidaridad.publicaciones p
        WHERE p.zona_id = ${query.zoneId} AND p.estado = 'abierta' AND p.eliminado_en IS NULL AND p.oculta_en IS NULL
          AND p.ubicacion IS NOT NULL AND (p.vence_en IS NULL OR p.vence_en > ${query.now})
          AND ST_DWithin(p.ubicacion, ${point}, ${query.radius})
      )
      SELECT * FROM cercanas
      WHERE (${cursorDistance}::double precision IS NULL OR (distancia, id) > (${cursorDistance}::double precision, ${query.cursor?.id ?? null}::uuid))
      ORDER BY distancia, id LIMIT ${query.limit + 1}
    `.execute(this.db);
    const data = rows
      .slice(0, query.limit)
      .map((row) => ({ post: toPost(row).snapshot(), distanceMeters: rounded(row.distancia) }));
    const last = data.at(-1);
    return {
      data,
      nextCursor:
        rows.length > query.limit && last ? { d: last.distanceMeters, id: last.post.id } : null,
    };
  }
  async insertIfAbsent(transaction: TransactionContext, post: Post): Promise<boolean> {
    const p = post.snapshot();
    await this.accounts.requireActiveWrite(transaction, p.authorId);
    await this.publication.requirePublication(transaction, p.authorId, p.createdAt);
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
      .where('oculta_en', 'is', null)
      .executeTakeFirst();
    return row ? toPost({ ...row, ubicacion: null }) : null;
  }

  async updateIfVersion(
    transaction: TransactionContext,
    post: Post,
    previousVersion: number,
  ): Promise<boolean> {
    const p = post.snapshot();
    if (p.status === 'en_curso' && p.takenById)
      await this.accounts.requireActiveWrite(transaction, p.takenById);
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
      .where('eliminado_en', 'is', null)
      .where('oculta_en', 'is', null)
      .executeTakeFirst();
    return Number(result.numUpdatedRows) === 1;
  }
}
