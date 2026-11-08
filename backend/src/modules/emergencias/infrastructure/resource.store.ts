import { Injectable } from '@nestjs/common';
import { sql } from 'kysely';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import { asKysely } from '../../../shared/db/unit-of-work.kysely.js';
import type { CellAggregate, ResourceStore } from '../application/ports.js';
import type { CriticalResource } from '../domain/emergency.js';

const fields =
  sql.raw(`id,zona_id AS "zoneId",reportante_id AS "reporterId",huella AS "creationFingerprint",tipo AS type,cantidad AS quantity,
  celda AS cell,reportado_en AS "reportedAt",umbral_segundos AS "staleAfterSeconds",verificacion AS verification,
  confirmaciones AS confirmations,etiqueta_publica AS "publicLabel",fuente_url AS "sourceUrl",oficial AS official,version`);

@Injectable()
export class PostgresResourceStore implements ResourceStore {
  async find(tx: TransactionContext, id: string): Promise<CriticalResource | null> {
    await sql`SELECT pg_advisory_xact_lock(hashtextextended(${`recurso:${id}`},0))`.execute(
      asKysely(tx),
    );
    return (
      (
        await sql<CriticalResource>`SELECT ${fields} FROM emergencias.recursos_criticos WHERE id = ${id} FOR UPDATE`.execute(
          asKysely(tx),
        )
      ).rows[0] ?? null
    );
  }
  async insert(tx: TransactionContext, resource: CriticalResource): Promise<void> {
    await sql`INSERT INTO emergencias.recursos_criticos(id,zona_id,reportante_id,huella,tipo,cantidad,celda,reportado_en,umbral_segundos)
      VALUES(${resource.id},${resource.zoneId},${resource.reporterId},${resource.creationFingerprint},${resource.type},${resource.quantity},${resource.cell},${resource.reportedAt},${resource.staleAfterSeconds})`.execute(
      asKysely(tx),
    );
    await this.publish(tx, resource.id);
  }
  async update(
    tx: TransactionContext,
    resource: CriticalResource,
    clearConfirmations: boolean,
  ): Promise<void> {
    if (clearConfirmations)
      await sql`DELETE FROM emergencias.confirmaciones_recursos WHERE recurso_id = ${resource.id}`.execute(
        asKysely(tx),
      );
    await sql`UPDATE emergencias.recursos_criticos SET cantidad = ${resource.quantity},reportado_en = ${resource.reportedAt},
      verificacion = ${resource.verification},confirmaciones = ${resource.confirmations},etiqueta_publica = ${resource.publicLabel},
      fuente_url = ${resource.sourceUrl},oficial = ${resource.official},version = ${resource.version} WHERE id = ${resource.id}`.execute(
      asKysely(tx),
    );
    await this.publish(tx, resource.id);
  }
  private async publish(tx: TransactionContext, id: string): Promise<void> {
    await sql`INSERT INTO emergencias.recursos_publicos SELECT id,zona_id,tipo,cantidad,celda,reportado_en,
      umbral_segundos,verificacion,confirmaciones,etiqueta_publica,fuente_url,oficial,version
      FROM emergencias.recursos_criticos WHERE id = ${id}
      ON CONFLICT(id) DO UPDATE SET cantidad = EXCLUDED.cantidad,reportado_en = EXCLUDED.reportado_en,
      verificacion = EXCLUDED.verificacion,confirmaciones = EXCLUDED.confirmaciones,
      etiqueta_publica = EXCLUDED.etiqueta_publica,fuente_url = EXCLUDED.fuente_url,
      oficial = EXCLUDED.oficial,version = EXCLUDED.version`.execute(asKysely(tx));
  }
  async confirm(tx: TransactionContext, id: string, userId: string, now: Date): Promise<void> {
    await sql`INSERT INTO emergencias.confirmaciones_recursos(recurso_id,usuario_id,confirmado_en)
      VALUES(${id},${userId},${now}) ON CONFLICT DO NOTHING`.execute(asKysely(tx));
  }
  async confirmationCount(tx: TransactionContext, id: string): Promise<number> {
    return (
      await sql<{
        count: number;
      }>`SELECT count(*)::int AS count FROM emergencias.confirmaciones_recursos WHERE recurso_id = ${id}`.execute(
        asKysely(tx),
      )
    ).rows[0]!.count;
  }
  async list(
    tx: TransactionContext,
    zoneId: string,
    cursor: string | undefined,
    limit: number,
  ): Promise<CriticalResource[]> {
    return (
      await sql<CriticalResource>`SELECT ${fields} FROM emergencias.recursos_criticos
      WHERE zona_id = ${zoneId} ${cursor ? sql`AND id > ${cursor}::uuid` : sql``} ORDER BY id LIMIT ${limit}`.execute(
        asKysely(tx),
      )
    ).rows;
  }
  async refreshAggregates(tx: TransactionContext, now: Date): Promise<void> {
    // Serialize snapshots. Suppressed values have no row and no complementary total.
    await sql`SELECT pg_advisory_xact_lock(hashtextextended('emergencias:agregados',0))`.execute(
      asKysely(tx),
    );
    await sql`DELETE FROM emergencias.agregados_celda`.execute(asKysely(tx));
    await sql`INSERT INTO emergencias.agregados_celda(id,zona_id,celda,necesidad,cantidad,actualizado_en)
      SELECT zona_id::text || ':' || celda || ':' || necesidad,zona_id,celda,necesidad,count(*)::int,${now}
      FROM emergencias.pedidos_ayuda WHERE cerrado_en IS NULL AND anonimizado_en IS NULL
        AND vence_en > ${now} AND celda IS NOT NULL AND zona_id IS NOT NULL
        AND evento_id IN (SELECT id FROM emergencias.eventos WHERE estado = 'emergencia')
      GROUP BY zona_id,celda,necesidad HAVING count(*) >= 3`.execute(asKysely(tx));
  }
  async aggregates(tx: TransactionContext, zoneId: string): Promise<CellAggregate[]> {
    return (
      await sql<CellAggregate>`SELECT id,zona_id AS "zoneId",celda AS cell,necesidad AS need,
      cantidad AS count,actualizado_en AS "updatedAt" FROM emergencias.agregados_celda
      WHERE zona_id = ${zoneId} ORDER BY id LIMIT 1000`.execute(asKysely(tx))
    ).rows;
  }
}
