import { Injectable } from '@nestjs/common';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import { asKysely } from '../../../shared/db/unit-of-work.kysely.js';
import type {
  ConsentDecision,
  ResidenceAccount,
  ResidenceStore,
} from '../application/residence-store.js';
import type { ConsentPurpose } from '../domain/consents.js';
import type { IdentityTables } from './tables.js';

const db = asKysely<IdentityTables>;

@Injectable()
export class KyselyResidenceStore implements ResidenceStore {
  async findActive(tx: TransactionContext, userId: string): Promise<ResidenceAccount | null> {
    const row = await db(tx)
      .selectFrom('identidad.usuarios')
      .select(['zona_id', 'zona_elegida_en', 'nivel_confianza', 'roles'])
      .where('id', '=', userId)
      .where('eliminado_en', 'is', null)
      .executeTakeFirst();
    return row
      ? {
          zoneId: row.zona_id,
          zoneChosenAt: row.zona_elegida_en,
          level: row.nivel_confianza,
          isModerator: row.roles.includes('moderador'),
        }
      : null;
  }

  async changeZone(
    tx: TransactionContext,
    userId: string,
    zoneId: string,
    now: Date,
  ): Promise<void> {
    const database = db(tx);
    await database
      .updateTable('identidad.usuarios')
      .set({ zona_id: zoneId, zona_elegida_en: now, nivel_confianza: 0, actualizado_en: now })
      .where('id', '=', userId)
      .execute();
    await this.clearPresences(tx, userId);
    await database
      .deleteFrom('identidad.avales')
      .where((eb) => eb.or([eb('vecino_id', '=', userId), eb('avalista_id', '=', userId)]))
      .execute();
  }

  async updateLevel(
    tx: TransactionContext,
    userId: string,
    level: number,
    now: Date,
  ): Promise<void> {
    await db(tx)
      .updateTable('identidad.usuarios')
      .set({ nivel_confianza: level, actualizado_en: now })
      .where('id', '=', userId)
      .execute();
  }

  async latestConsent(
    tx: TransactionContext,
    userId: string,
    purpose: ConsentPurpose,
  ): Promise<ConsentDecision | null> {
    const row = await db(tx)
      .selectFrom('identidad.consentimientos')
      .select(['version', 'aceptado', 'decidido_en'])
      .where('usuario_id', '=', userId)
      .where('finalidad', '=', purpose)
      .orderBy('id', 'desc')
      .executeTakeFirst();
    return row
      ? { version: row.version, accepted: row.aceptado, decidedAt: row.decidido_en }
      : null;
  }

  async recordConsent(
    tx: TransactionContext,
    userId: string,
    purpose: ConsentPurpose,
    decision: ConsentDecision,
  ): Promise<void> {
    await db(tx)
      .insertInto('identidad.consentimientos')
      .values({
        usuario_id: userId,
        finalidad: purpose,
        version: decision.version,
        aceptado: decision.accepted,
        decidido_en: decision.decidedAt,
      })
      .execute();
  }

  async recordPresence(
    tx: TransactionContext,
    userId: string,
    day: string,
    inside: boolean,
  ): Promise<void> {
    await db(tx)
      .insertInto('identidad.presencias')
      .values({
        usuario_id: userId,
        fecha: day,
        dentro_de_la_zona: inside,
      })
      .onConflict((oc) => oc.columns(['usuario_id', 'fecha']).doNothing())
      .execute();
  }

  async countPresenceDays(
    tx: TransactionContext,
    userId: string,
    since: string,
    until: string,
  ): Promise<number> {
    const row = await db(tx)
      .selectFrom('identidad.presencias')
      .select((eb) => eb.fn.countAll().as('total'))
      .where('usuario_id', '=', userId)
      .where('dentro_de_la_zona', '=', true)
      .where('fecha', '>=', since)
      .where('fecha', '<=', until)
      .executeTakeFirstOrThrow();
    return Number(row.total);
  }

  async clearPresences(tx: TransactionContext, userId: string): Promise<void> {
    await db(tx).deleteFrom('identidad.presencias').where('usuario_id', '=', userId).execute();
  }

  async expirePresences(tx: TransactionContext, cutoff: string): Promise<void> {
    await db(tx).deleteFrom('identidad.presencias').where('fecha', '<=', cutoff).execute();
  }

  async recordConfirmation(
    tx: TransactionContext,
    userId: string,
    zoneId: string,
    moderatorId: string,
    reason: string,
    level: 1 | 2,
    now: Date,
  ): Promise<void> {
    await db(tx)
      .insertInto('identidad.confirmaciones')
      .values({
        vecino_id: userId,
        zona_id: zoneId,
        moderador_id: moderatorId,
        motivo: reason,
        nivel: level,
        creada_en: now,
      })
      .execute();
  }

  async recordEndorsement(
    tx: TransactionContext,
    userId: string,
    zoneId: string,
    endorserId: string,
    now: Date,
  ): Promise<void> {
    await db(tx)
      .insertInto('identidad.avales')
      .values({
        vecino_id: userId,
        zona_id: zoneId,
        avalista_id: endorserId,
        creado_en: now,
      })
      .onConflict((oc) => oc.columns(['vecino_id', 'avalista_id']).doNothing())
      .execute();
  }

  async countEndorsements(tx: TransactionContext, userId: string, zoneId: string): Promise<number> {
    const row = await db(tx)
      .selectFrom('identidad.avales')
      .innerJoin('identidad.usuarios as avalista', 'avalista.id', 'identidad.avales.avalista_id')
      .select((eb) => eb.fn.countAll().as('total'))
      .where('identidad.avales.vecino_id', '=', userId)
      .where('identidad.avales.zona_id', '=', zoneId)
      .where('avalista.zona_id', '=', zoneId)
      .where('avalista.nivel_confianza', '>=', 2)
      .where('avalista.eliminado_en', 'is', null)
      .executeTakeFirstOrThrow();
    return Number(row.total);
  }
}
