import { Injectable } from '@nestjs/common';
import { sql } from 'kysely';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import { asJsonb, asKysely } from '../../../shared/db/unit-of-work.kysely.js';
import type {
  AggregateSnapshot,
  AggregateVersion,
  CategoryRatingFacts,
  DirectoryRankingStore,
  DirectoryServiceReader,
  ServiceForReputation,
} from '../application/reputation-ports.js';
import { averageRating } from '../domain/reputation-ranking.js';
import type { DirectoryTables } from './tables.js';

@Injectable()
export class KyselyDirectoryReputationStore
  implements DirectoryServiceReader, DirectoryRankingStore
{
  async findForReputation(
    transaction: TransactionContext,
    id: string,
  ): Promise<ServiceForReputation | null> {
    const { rows } = await sql<{ proveedor_id: string; zona_id: string; vigente: boolean }>`
      SELECT s.proveedor_id, s.zona_id,
        (s.eliminado_en IS NULL AND s.oculto_en IS NULL AND p.eliminado_en IS NULL
          AND p.oculto_en IS NULL AND s.zona_id = p.zona_id) AS vigente
      FROM directorio.servicios s
      JOIN directorio.proveedores p ON p.id = s.proveedor_id
      WHERE s.id = ${id}
    `.execute(asKysely(transaction));
    const service = rows[0];
    return service
      ? { providerId: service.proveedor_id, zoneId: service.zona_id, active: service.vigente }
      : null;
  }

  async applyFacts(
    transaction: TransactionContext,
    facts: AggregateSnapshot,
    version: AggregateVersion,
    now: Date,
  ): Promise<string | null> {
    const db = asKysely<DirectoryTables>(transaction);
    // Serialize updates that can change the category mean, including concurrent workers.
    await sql`SELECT pg_advisory_xact_lock(hashtextextended('directorio:reputacion', 0))`.execute(
      db,
    );
    const service = await db
      .selectFrom('directorio.servicios')
      .select('categoria_id')
      .where('id', '=', facts.servicioId)
      .forUpdate()
      .executeTakeFirst();
    if (!service) return null;
    const marker = await sql<{ servicio_id: string }>`
      INSERT INTO directorio.recalculos_reputacion AS anterior (servicio_id, evento_id, ocurrido_en)
      VALUES (${facts.servicioId}, ${version.eventId}, ${version.occurredAt})
      ON CONFLICT (servicio_id) DO UPDATE
        SET evento_id = EXCLUDED.evento_id, ocurrido_en = EXCLUDED.ocurrido_en
      WHERE (anterior.ocurrido_en, anterior.evento_id) < (EXCLUDED.ocurrido_en, EXCLUDED.evento_id)
      RETURNING servicio_id
    `.execute(db);
    if (!marker.rows.length) return null;
    const average = sql<number>`round(${averageRating(facts.sumaCalificaciones, facts.totalResenas)}::numeric, 2)`;
    await db
      .updateTable('directorio.servicios')
      .set({
        total_resenas: facts.totalResenas,
        suma_calificaciones: facts.sumaCalificaciones,
        promedio: average,
        total_vistos_buenos: facts.totalVistosBuenos,
        vistos_buenos_de_la_zona: facts.vistosBuenosDeLaZona,
        actualizado_en: sql<Date>`greatest(actualizado_en, ${now})`,
      })
      .where('id', '=', facts.servicioId)
      .where((eb) =>
        eb.or([
          eb('total_resenas', '!=', facts.totalResenas),
          eb('suma_calificaciones', '!=', facts.sumaCalificaciones),
          eb('promedio', '!=', average),
          eb('total_vistos_buenos', '!=', facts.totalVistosBuenos),
          eb('vistos_buenos_de_la_zona', '!=', facts.vistosBuenosDeLaZona),
        ]),
      )
      .execute();
    return service.categoria_id;
  }

  async categoryFacts(
    transaction: TransactionContext,
    categoryId: string,
  ): Promise<CategoryRatingFacts[]> {
    const { rows } = await sql<CategoryRatingFacts>`
      SELECT s.id, s.total_resenas AS "reviewCount", s.suma_calificaciones AS "ratingSum"
      FROM directorio.servicios s
      JOIN directorio.proveedores p ON p.id = s.proveedor_id AND p.zona_id = s.zona_id
      WHERE s.categoria_id = ${categoryId} AND s.eliminado_en IS NULL AND s.oculto_en IS NULL
        AND p.eliminado_en IS NULL AND p.oculto_en IS NULL
    `.execute(asKysely(transaction));
    return rows;
  }

  async saveScores(
    transaction: TransactionContext,
    categoryId: string,
    scores: readonly { id: string; score: number }[],
    now: Date,
  ): Promise<void> {
    if (!scores.length) return;
    const payload = asJsonb(scores.map(({ id, score }) => ({ id, puntaje: score })));
    await sql`
      UPDATE directorio.servicios s
      SET puntaje_ranking = r.puntaje, actualizado_en = greatest(s.actualizado_en, ${now})
      FROM jsonb_to_recordset(${payload}) AS r(id uuid, puntaje numeric(6,4))
      WHERE s.id = r.id AND s.categoria_id = ${categoryId}
        AND s.eliminado_en IS NULL AND s.oculto_en IS NULL
        AND s.puntaje_ranking IS DISTINCT FROM r.puntaje
    `.execute(asKysely(transaction));
  }
}
