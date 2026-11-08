import { Injectable } from '@nestjs/common';
import { sql } from 'kysely';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import { asKysely } from '../../../shared/db/unit-of-work.kysely.js';
import type { GrantEvidence, OperationsStore } from '../application/ports.js';
import type {
  DutyShift,
  OperationalGrant,
  OperationalRole,
  SupportGroup,
} from '../domain/emergency.js';

const grantFields = sql.raw(`id,usuario_id AS "userId",zona_id AS "zoneId",rol AS role,
  vence_en AS "expiresAt",revocada_en AS "revokedAt",version`);
const shiftFields = sql.raw(`id,usuario_id AS "userId",zona_id AS "zoneId",rol AS role,
  inicio AS "startsAt",fin AS "endsAt",finalizado_en AS "endedAt",version`);
const groupFields =
  sql.raw(`g.id,g.zona_id AS "zoneId",g.nombre AS name,g.verificado_en AS "verifiedAt",g.version,
  ARRAY(SELECT m.usuario_id FROM emergencias.miembros_grupo m WHERE m.grupo_id = g.id ORDER BY m.usuario_id) AS members`);

@Injectable()
export class PostgresOperationsStore implements OperationsStore {
  async lockUser(tx: TransactionContext, userId: string): Promise<void> {
    await sql`SELECT pg_advisory_xact_lock(hashtextextended(${`operador:${userId}`},0))`.execute(
      asKysely(tx),
    );
  }
  async grants(tx: TransactionContext, zoneId: string, now: Date): Promise<OperationalGrant[]> {
    return (
      await sql<OperationalGrant>`SELECT ${grantFields} FROM emergencias.habilitaciones
      WHERE zona_id = ${zoneId} AND revocada_en IS NULL AND vence_en > ${now} ORDER BY usuario_id,rol LIMIT 500`.execute(
        asKysely(tx),
      )
    ).rows;
  }
  async grant(tx: TransactionContext, id: string): Promise<OperationalGrant | null> {
    return (
      (
        await sql<OperationalGrant>`SELECT ${grantFields} FROM emergencias.habilitaciones
      WHERE id = ${id} FOR UPDATE`.execute(asKysely(tx))
      ).rows[0] ?? null
    );
  }
  async grantFor(
    tx: TransactionContext,
    userId: string,
    zoneId: string,
    role: OperationalRole,
  ): Promise<OperationalGrant | null> {
    return (
      (
        await sql<OperationalGrant>`SELECT ${grantFields} FROM emergencias.habilitaciones
      WHERE usuario_id = ${userId} AND zona_id = ${zoneId} AND rol = ${role} FOR UPDATE`.execute(
          asKysely(tx),
        )
      ).rows[0] ?? null
    );
  }
  async saveGrant(
    tx: TransactionContext,
    grant: OperationalGrant,
    evidence: GrantEvidence,
  ): Promise<OperationalGrant> {
    return (
      await sql<OperationalGrant>`INSERT INTO emergencias.habilitaciones(id,usuario_id,zona_id,rol,
      dni_revisado_en,capacitacion_en,confidencialidad_en,referencia_revision,revisada_por,vence_en)
      VALUES(${grant.id},${grant.userId},${grant.zoneId},${grant.role},${evidence.dniReviewedAt},
      ${evidence.trainedAt},${evidence.confidentialityAt},${evidence.reviewReference},${evidence.reviewedBy},${grant.expiresAt})
      ON CONFLICT(usuario_id,zona_id,rol) DO UPDATE SET dni_revisado_en = EXCLUDED.dni_revisado_en,
      capacitacion_en = EXCLUDED.capacitacion_en,confidencialidad_en = EXCLUDED.confidencialidad_en,
      referencia_revision = EXCLUDED.referencia_revision,revisada_por = EXCLUDED.revisada_por,
      vence_en = EXCLUDED.vence_en,revocada_en = NULL,version = emergencias.habilitaciones.version + 1
      RETURNING ${grantFields}`.execute(asKysely(tx))
    ).rows[0]!;
  }
  async revoke(
    tx: TransactionContext,
    grant: OperationalGrant,
    now: Date,
  ): Promise<OperationalGrant> {
    return (
      await sql<OperationalGrant>`UPDATE emergencias.habilitaciones SET revocada_en = ${now},
      version = version + 1 WHERE id = ${grant.id} RETURNING ${grantFields}`.execute(asKysely(tx))
    ).rows[0]!;
  }
  async activeGrants(
    tx: TransactionContext,
    userId: string,
    role: OperationalRole,
    now: Date,
  ): Promise<number> {
    return (
      await sql<{ count: number }>`SELECT count(*)::int AS count FROM emergencias.habilitaciones
      WHERE usuario_id = ${userId} AND rol = ${role} AND revocada_en IS NULL AND vence_en > ${now}`.execute(
        asKysely(tx),
      )
    ).rows[0]!.count;
  }
  async shifts(tx: TransactionContext, zoneId: string, now: Date): Promise<DutyShift[]> {
    return (
      await sql<DutyShift>`SELECT ${shiftFields} FROM emergencias.turnos WHERE zona_id = ${zoneId}
      AND fin > ${new Date(now.getTime() - 86400000)} ORDER BY inicio,id LIMIT 500`.execute(
        asKysely(tx),
      )
    ).rows;
  }
  async shift(tx: TransactionContext, id: string): Promise<DutyShift | null> {
    return (
      (
        await sql<DutyShift>`SELECT ${shiftFields} FROM emergencias.turnos WHERE id = ${id} FOR UPDATE`.execute(
          asKysely(tx),
        )
      ).rows[0] ?? null
    );
  }
  async insertShift(tx: TransactionContext, shift: DutyShift): Promise<DutyShift> {
    await sql`INSERT INTO emergencias.turnos(id,usuario_id,zona_id,rol,inicio,fin)
      VALUES(${shift.id},${shift.userId},${shift.zoneId},${shift.role},${shift.startsAt},${shift.endsAt})`.execute(
      asKysely(tx),
    );
    return shift;
  }
  async endShift(tx: TransactionContext, shift: DutyShift, now: Date): Promise<DutyShift> {
    return (
      await sql<DutyShift>`UPDATE emergencias.turnos SET finalizado_en = ${now},version = version + 1
      WHERE id = ${shift.id} RETURNING ${shiftFields}`.execute(asKysely(tx))
    ).rows[0]!;
  }
  async overlapsShift(tx: TransactionContext, shift: DutyShift): Promise<boolean> {
    const result = await sql`SELECT 1 FROM emergencias.turnos WHERE usuario_id = ${shift.userId}
      AND finalizado_en IS NULL AND inicio < ${shift.endsAt} AND fin > ${shift.startsAt} LIMIT 1`.execute(
      asKysely(tx),
    );
    return result.rows.length > 0;
  }
  async finishAssignments(
    tx: TransactionContext,
    userId: string,
    now: Date,
    role?: 'coordinador' | 'brigadista',
  ): Promise<void> {
    await sql`UPDATE emergencias.asignaciones a SET finalizada_en = ${now}
      WHERE a.usuario_id = ${userId} AND a.finalizada_en IS NULL ${role ? sql`AND a.rol = ${role}` : sql``}`.execute(
      asKysely(tx),
    );
  }
  async groups(tx: TransactionContext, zoneId: string): Promise<SupportGroup[]> {
    return (
      await sql<SupportGroup>`SELECT ${groupFields} FROM emergencias.grupos_apoyo g
      WHERE zona_id = ${zoneId} ORDER BY g.id LIMIT 100`.execute(asKysely(tx))
    ).rows;
  }
  async group(tx: TransactionContext, id: string): Promise<SupportGroup | null> {
    return (
      (
        await sql<SupportGroup>`SELECT ${groupFields} FROM emergencias.grupos_apoyo g
      WHERE g.id = ${id} FOR UPDATE OF g`.execute(asKysely(tx))
      ).rows[0] ?? null
    );
  }
  async saveGroup(tx: TransactionContext, group: SupportGroup): Promise<SupportGroup> {
    await sql`INSERT INTO emergencias.grupos_apoyo(id,zona_id,nombre,verificado_en,version)
      VALUES(${group.id},${group.zoneId},${group.name},${group.verifiedAt},${group.version})
      ON CONFLICT(id) DO UPDATE SET version = EXCLUDED.version`.execute(asKysely(tx));
    await sql`DELETE FROM emergencias.miembros_grupo WHERE grupo_id = ${group.id}`.execute(
      asKysely(tx),
    );
    for (const userId of group.members)
      await sql`INSERT INTO emergencias.miembros_grupo(grupo_id,usuario_id)
      VALUES(${group.id},${userId})`.execute(asKysely(tx));
    return group;
  }
  async setSupportZones(
    tx: TransactionContext,
    zoneId: string,
    zones: readonly string[],
  ): Promise<void> {
    await sql`DELETE FROM emergencias.zonas_apoyo WHERE zona_id = ${zoneId}`.execute(asKysely(tx));
    for (const target of zones)
      await sql`INSERT INTO emergencias.zonas_apoyo(zona_id,apoyo_zona_id)
      VALUES(${zoneId},${target})`.execute(asKysely(tx));
    await sql`UPDATE emergencias.asignaciones a SET finalizada_en = now()
      FROM emergencias.pedidos_ayuda p,emergencias.habilitaciones h
      WHERE p.id = a.pedido_id AND p.zona_id = ${zoneId} AND a.finalizada_en IS NULL
      AND h.usuario_id = a.usuario_id AND h.rol = a.rol AND h.revocada_en IS NULL AND h.zona_id <> p.zona_id
      AND NOT EXISTS(SELECT 1 FROM emergencias.zonas_apoyo z WHERE z.zona_id = p.zona_id AND z.apoyo_zona_id = h.zona_id)`.execute(
      asKysely(tx),
    );
  }
  async supportZones(tx: TransactionContext, zoneId: string): Promise<string[]> {
    return (
      await sql<{ id: string }>`SELECT apoyo_zona_id AS id FROM emergencias.zonas_apoyo
      WHERE zona_id = ${zoneId} ORDER BY apoyo_zona_id`.execute(asKysely(tx))
    ).rows.map((row) => row.id);
  }
  async expireAssignments(tx: TransactionContext, now: Date): Promise<void> {
    await sql`UPDATE emergencias.asignaciones a SET finalizada_en = ${now}
      WHERE a.finalizada_en IS NULL AND (a.acceso_hasta <= ${now} OR NOT EXISTS (
        SELECT 1 FROM emergencias.habilitaciones h WHERE h.usuario_id = a.usuario_id AND h.rol = a.rol
          AND h.revocada_en IS NULL AND h.vence_en > ${now}
      ))`.execute(asKysely(tx));
  }
}
