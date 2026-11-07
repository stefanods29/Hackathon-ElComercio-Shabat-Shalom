import { Inject, Injectable } from '@nestjs/common';
import { type Kysely, type Selectable, sql } from 'kysely';
import { KYSELY } from '../../../shared/db/connection.js';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import { asKysely } from '../../../shared/db/unit-of-work.kysely.js';
import type {
  OtpCodeRecord,
  OtpCodeRepository,
  OtpFailureScope,
  OtpFailureState,
} from '../application/ports.js';
import type { IdentityTables, OtpCodesTable } from './tables.js';

function toRecord(row: Selectable<OtpCodesTable>): OtpCodeRecord {
  return {
    id: row.id,
    phone: row.telefono,
    codeHash: row.codigo_hash,
    channel: row.canal,
    ip: row.ip,
    attempts: row.intentos,
    expiresAt: row.expira_en,
    usedAt: row.usado_en,
    createdAt: row.creado_en,
  };
}

@Injectable()
export class KyselyOtpCodeRepository implements OtpCodeRepository {
  constructor(@Inject(KYSELY) private readonly db: Kysely<IdentityTables>) {}

  async lockPhoneAndIp(
    transaction: TransactionContext,
    phone: string,
    ip: string | null,
  ): Promise<string | null> {
    const db = asKysely<IdentityTables>(transaction);
    const normalizedIp = ip
      ? (await sql<{ ip: string }>`SELECT host(${ip}::inet) AS ip`.execute(db)).rows[0]!.ip
      : null;
    const keys = [
      `otp:telefono:${phone}`,
      ...(normalizedIp ? [`otp:ip:${normalizedIp}`] : []),
    ].sort();
    for (const key of keys) {
      await sql`SELECT pg_advisory_xact_lock(hashtext(${key})::bigint)`.execute(db);
    }
    return normalizedIp;
  }

  async findFailureState(
    transaction: TransactionContext,
    scope: OtpFailureScope,
    key: string,
  ): Promise<OtpFailureState | null> {
    const row = await asKysely<IdentityTables>(transaction)
      .selectFrom('identidad.limites_otp')
      .selectAll()
      .where('ambito', '=', scope)
      .where('identificador', '=', key)
      .executeTakeFirst();
    return row
      ? {
          attempts: row.intentos,
          windowStartedAt: row.ventana_desde,
          blockedUntil: row.bloqueado_hasta,
        }
      : null;
  }

  async saveFailureState(
    transaction: TransactionContext,
    scope: OtpFailureScope,
    key: string,
    state: OtpFailureState,
  ): Promise<void> {
    const values = {
      intentos: state.attempts,
      ventana_desde: state.windowStartedAt,
      bloqueado_hasta: state.blockedUntil,
    };
    await asKysely<IdentityTables>(transaction)
      .insertInto('identidad.limites_otp')
      .values({ ambito: scope, identificador: key, ...values })
      .onConflict((conflict) => conflict.columns(['ambito', 'identificador']).doUpdateSet(values))
      .execute();
  }

  async clearFailureState(
    transaction: TransactionContext,
    scope: OtpFailureScope,
    key: string,
  ): Promise<void> {
    await asKysely<IdentityTables>(transaction)
      .deleteFrom('identidad.limites_otp')
      .where('ambito', '=', scope)
      .where('identificador', '=', key)
      .execute();
  }

  async create(transaction: TransactionContext, record: OtpCodeRecord): Promise<void> {
    await asKysely<IdentityTables>(transaction)
      .insertInto('identidad.codigos_otp')
      .values({
        id: record.id,
        telefono: record.phone,
        codigo_hash: record.codeHash,
        canal: record.channel,
        ip: record.ip,
        intentos: record.attempts,
        expira_en: record.expiresAt,
        usado_en: record.usedAt,
        creado_en: record.createdAt,
      })
      .execute();
  }

  async findLatestActiveForUpdate(
    transaction: TransactionContext,
    phone: string,
    now: Date,
  ): Promise<OtpCodeRecord | null> {
    const row = await asKysely<IdentityTables>(transaction)
      .selectFrom('identidad.codigos_otp')
      .selectAll()
      .where('telefono', '=', phone)
      .where('usado_en', 'is', null)
      .where('expira_en', '>', now)
      .orderBy('creado_en', 'desc')
      .orderBy('id', 'desc')
      .limit(1)
      .forUpdate()
      .executeTakeFirst();
    return row ? toRecord(row) : null;
  }

  async countByPhoneSince(
    phone: string,
    since: Date,
    transaction?: TransactionContext,
  ): Promise<{ count: number; oldest: Date | null }> {
    const { rows } = await sql<{ count: number; oldest: Date | null }>`
      SELECT count(*)::int AS count, min(creado_en) AS oldest
      FROM identidad.codigos_otp
      WHERE telefono = ${phone} AND creado_en >= ${since}
    `.execute(this.reader(transaction));
    return rows[0] ?? { count: 0, oldest: null };
  }

  async countByIpSince(
    ip: string,
    since: Date,
    transaction?: TransactionContext,
  ): Promise<{ count: number; oldest: Date | null }> {
    const { rows } = await sql<{ count: number; oldest: Date | null }>`
      SELECT count(*)::int AS count, min(creado_en) AS oldest
      FROM identidad.codigos_otp
      WHERE ip = ${ip}::inet AND creado_en >= ${since}
    `.execute(this.reader(transaction));
    return rows[0] ?? { count: 0, oldest: null };
  }

  async incrementAttempts(transaction: TransactionContext, id: string): Promise<number> {
    const row = await asKysely<IdentityTables>(transaction)
      .updateTable('identidad.codigos_otp')
      .set({ intentos: sql`intentos + 1` })
      .where('id', '=', id)
      .returning('intentos')
      .executeTakeFirstOrThrow();
    return row.intentos;
  }

  async markUsed(transaction: TransactionContext, id: string, now: Date): Promise<boolean> {
    const row = await asKysely<IdentityTables>(transaction)
      .updateTable('identidad.codigos_otp')
      .set({ usado_en: now })
      .where('id', '=', id)
      .where('usado_en', 'is', null)
      .returning('id')
      .executeTakeFirst();
    return row !== undefined;
  }

  private reader(transaction?: TransactionContext) {
    return transaction ? asKysely<IdentityTables>(transaction) : this.db;
  }
}
