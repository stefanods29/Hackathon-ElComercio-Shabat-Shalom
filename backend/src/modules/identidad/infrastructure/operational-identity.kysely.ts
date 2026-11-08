import { Injectable } from '@nestjs/common';
import { sql } from 'kysely';
import type { Role } from '../../../shared/auth/actor.js';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import { asKysely } from '../../../shared/db/unit-of-work.kysely.js';
import type {
  OperationalAccount,
  OperationalIdentity,
} from '../application/operational-identity.js';

@Injectable()
export class KyselyOperationalIdentity implements OperationalIdentity {
  async find(tx: TransactionContext, userId: string): Promise<OperationalAccount | null> {
    const result = await sql<OperationalAccount>`SELECT id, zona_id AS "zoneId",
      nombre_visible AS "displayName", nivel_confianza AS "trustLevel", roles
      FROM identidad.usuarios WHERE id = ${userId} AND eliminado_en IS NULL FOR SHARE`.execute(
      asKysely(tx),
    );
    return result.rows[0] ?? null;
  }
  async certify(tx: TransactionContext, userId: string, role: Role, now: Date): Promise<void> {
    await sql`UPDATE identidad.usuarios SET nivel_confianza = 3,
      roles = CASE WHEN ${role} = ANY(roles) THEN roles ELSE array_append(roles, ${role}) END,
      actualizado_en = ${now} WHERE id = ${userId} AND eliminado_en IS NULL`.execute(asKysely(tx));
  }
  async removeRole(tx: TransactionContext, userId: string, role: Role, now: Date): Promise<void> {
    await sql`UPDATE identidad.usuarios SET roles = array_remove(roles, ${role}), actualizado_en = ${now}
      WHERE id = ${userId}`.execute(asKysely(tx));
  }
  async zoneExists(tx: TransactionContext, zoneId: string): Promise<boolean> {
    const result = await sql`SELECT id FROM identidad.zonas WHERE id = ${zoneId}`.execute(
      asKysely(tx),
    );
    return result.rows.length === 1;
  }
  async contains(
    tx: TransactionContext,
    zoneId: string,
    lat: number,
    lng: number,
  ): Promise<boolean> {
    const result = await sql<{ covered: boolean }>`SELECT ST_Covers(limite::geometry,
      ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)) AS covered
      FROM identidad.zonas WHERE id = ${zoneId}`.execute(asKysely(tx));
    return result.rows[0]?.covered === true;
  }
}
