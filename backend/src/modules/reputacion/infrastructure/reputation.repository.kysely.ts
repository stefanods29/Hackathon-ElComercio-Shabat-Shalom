import { Injectable } from '@nestjs/common';
import { PublicationPolicy } from '../../moderacion/index.js';
import { AccountAccess } from '../../../shared/auth/account-access.js';
import { type Selectable, sql } from 'kysely';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import { asKysely } from '../../../shared/db/unit-of-work.kysely.js';
import type { ReputationFacts, ReputationRepository } from '../application/ports.js';
import {
  MIN_RANKING_TRUST_LEVEL,
  type Endorsement,
  type EndorsementData,
} from '../domain/endorsement.js';
import type { Review, ReviewProps } from '../domain/review.js';
import type { EndorsementsTable, ReputationTables } from './tables.js';

function toEndorsement(row: Selectable<EndorsementsTable>): Endorsement {
  return {
    id: row.id,
    serviceId: row.servicio_id,
    neighborId: row.vecino_id,
    neighborZoneId: row.zona_vecino_id,
    trustLevelAtGiving: row.nivel_al_dar,
    createdAt: row.creado_en,
  };
}

@Injectable()
export class KyselyReputationRepository implements ReputationRepository {
  constructor(
    private readonly accounts: AccountAccess,
    private readonly publication: PublicationPolicy,
  ) {}

  private async lock(transaction: TransactionContext, key: string): Promise<void> {
    await sql`SELECT pg_advisory_xact_lock(hashtextextended(${key}, 0))`.execute(
      asKysely(transaction),
    );
  }

  lockAuthor(transaction: TransactionContext, authorId: string): Promise<void> {
    return this.lock(transaction, `reputacion:autor:${authorId}`);
  }

  lockService(transaction: TransactionContext, serviceId: string): Promise<void> {
    return this.lock(transaction, `reputacion:servicio:${serviceId}`);
  }

  async findReview(transaction: TransactionContext, id: string): Promise<ReviewProps | null> {
    const db = asKysely<ReputationTables>(transaction);
    const row = await db
      .selectFrom('reputacion.resenas')
      .selectAll()
      .where('id', '=', id)
      .executeTakeFirst();
    if (!row) return null;
    const photos = await db
      .selectFrom('reputacion.resena_fotos')
      .selectAll()
      .where('resena_id', '=', id)
      .orderBy('orden')
      .execute();
    return {
      id: row.id,
      serviceId: row.servicio_id,
      authorId: row.autor_id,
      authorZoneId: row.zona_autor_id,
      rating: row.calificacion,
      comment: row.comentario,
      state: row.estado,
      stateReason: row.motivo_estado,
      createdAt: row.creado_en,
      updatedAt: row.actualizado_en,
      publishedAt: row.publicada_en,
      photos: photos.map((photo) => ({
        id: photo.id,
        fileId: photo.archivo_id,
        order: photo.orden,
        width: photo.ancho,
        height: photo.alto,
        blurhash: photo.blurhash,
        hiddenAt: photo.oculta_en,
      })),
    };
  }

  async hasReview(
    transaction: TransactionContext,
    serviceId: string,
    authorId: string,
  ): Promise<boolean> {
    const row = await asKysely<ReputationTables>(transaction)
      .selectFrom('reputacion.resenas')
      .select('id')
      .where('servicio_id', '=', serviceId)
      .where('autor_id', '=', authorId)
      .executeTakeFirst();
    return row !== undefined;
  }

  async countReviewsSince(
    transaction: TransactionContext,
    authorId: string,
    since: Date,
  ): Promise<{ count: number; oldest: Date | null }> {
    const { rows } = await sql<{ count: number; oldest: Date | null }>`
      SELECT count(*)::int AS count, min(creado_en) AS oldest FROM reputacion.resenas
      WHERE autor_id = ${authorId} AND creado_en > ${since}
    `.execute(asKysely(transaction));
    return rows[0]!;
  }

  async insertReview(
    transaction: TransactionContext,
    review: Review,
    deviceHash: string | null,
  ): Promise<boolean> {
    const db = asKysely<ReputationTables>(transaction);
    const r = review.snapshot();
    await this.accounts.requireActiveWrite(transaction, r.authorId);
    await this.publication.requirePublication(transaction, r.authorId, r.createdAt);
    const inserted = await db
      .insertInto('reputacion.resenas')
      .values({
        id: r.id,
        servicio_id: r.serviceId,
        autor_id: r.authorId,
        zona_autor_id: r.authorZoneId,
        calificacion: r.rating,
        comentario: r.comment,
        estado: r.state,
        motivo_estado: r.stateReason,
        creado_en: r.createdAt,
        actualizado_en: r.updatedAt,
        publicada_en: r.publishedAt,
      })
      .onConflict((conflict) => conflict.doNothing())
      .returning('id')
      .executeTakeFirst();
    if (!inserted) return false;
    if (r.photos.length) {
      await db
        .insertInto('reputacion.resena_fotos')
        .values(
          r.photos.map((photo) => ({
            id: photo.id,
            resena_id: r.id,
            archivo_id: photo.fileId,
            orden: photo.order,
            ancho: photo.width,
            alto: photo.height,
            blurhash: photo.blurhash,
            oculta_en: photo.hiddenAt,
          })),
        )
        .execute();
    }
    if (deviceHash) {
      await db
        .insertInto('reputacion.senales_resenas')
        .values({
          resena_id: r.id,
          dispositivo_hash: deviceHash,
          creado_en: r.createdAt,
        })
        .execute();
    }
    return true;
  }

  async findEndorsement(
    transaction: TransactionContext,
    serviceId: string,
    neighborId: string,
  ): Promise<Endorsement | null> {
    const row = await asKysely<ReputationTables>(transaction)
      .selectFrom('reputacion.vistos_buenos')
      .selectAll()
      .where('servicio_id', '=', serviceId)
      .where('vecino_id', '=', neighborId)
      .executeTakeFirst();
    return row ? toEndorsement(row) : null;
  }

  async insertEndorsement(
    transaction: TransactionContext,
    data: EndorsementData,
  ): Promise<Endorsement | null> {
    await this.accounts.requireActiveWrite(transaction, data.neighborId);
    const row = await asKysely<ReputationTables>(transaction)
      .insertInto('reputacion.vistos_buenos')
      .values({
        servicio_id: data.serviceId,
        vecino_id: data.neighborId,
        zona_vecino_id: data.neighborZoneId,
        nivel_al_dar: data.trustLevelAtGiving,
        creado_en: data.createdAt,
      })
      .onConflict((conflict) => conflict.columns(['servicio_id', 'vecino_id']).doNothing())
      .returningAll()
      .executeTakeFirst();
    return row ? toEndorsement(row) : null;
  }

  async deleteEndorsement(
    transaction: TransactionContext,
    serviceId: string,
    neighborId: string,
  ): Promise<boolean> {
    const result = await asKysely<ReputationTables>(transaction)
      .deleteFrom('reputacion.vistos_buenos')
      .where('servicio_id', '=', serviceId)
      .where('vecino_id', '=', neighborId)
      .executeTakeFirst();
    return Number(result.numDeletedRows) > 0;
  }

  async aggregateFacts(
    transaction: TransactionContext,
    serviceId: string,
    zoneId: string,
  ): Promise<ReputationFacts> {
    const { rows } = await sql<ReputationFacts>`
      WITH resenas AS (
        SELECT count(*)::int AS cantidad, coalesce(sum(calificacion), 0)::int AS suma
        FROM reputacion.resenas WHERE servicio_id = ${serviceId} AND estado = 'publicada'
      ), vistos AS (
        SELECT count(*)::int AS cantidad,
          (count(*) FILTER (WHERE nivel_al_dar >= ${MIN_RANKING_TRUST_LEVEL} AND zona_vecino_id = ${zoneId}))::int AS de_zona
        FROM reputacion.vistos_buenos WHERE servicio_id = ${serviceId}
      )
      SELECT resenas.cantidad AS "reviewCount", resenas.suma AS "ratingSum",
        vistos.cantidad AS "endorsementCount", vistos.de_zona AS "zoneEndorsementCount"
      FROM resenas CROSS JOIN vistos
    `.execute(asKysely(transaction));
    return rows[0]!;
  }

  async countDeviceReviewsForPendingReview(
    transaction: TransactionContext,
    reviewId: string,
  ): Promise<number> {
    const { rows } = await sql<{ count: number }>`
      SELECT count(*)::int AS count
      FROM reputacion.resenas r
      JOIN reputacion.senales_resenas senal ON senal.resena_id = r.id
      JOIN reputacion.senales_resenas otra ON otra.dispositivo_hash = senal.dispositivo_hash
        AND otra.creado_en > senal.creado_en - interval '24 hours'
        AND (otra.creado_en, otra.resena_id) <= (senal.creado_en, senal.resena_id)
      WHERE r.id = ${reviewId} AND r.estado = 'en_revision'
    `.execute(asKysely(transaction));
    return rows[0]!.count;
  }
}
