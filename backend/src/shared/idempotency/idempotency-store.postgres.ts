import { type Kysely, sql } from 'kysely';
import { validate as isUuid } from 'uuid';
import type { AccountAccess } from '../auth/account-access.js';
import type { SharedTables } from '../db/shared-tables.js';
import { KyselyUnitOfWork, asJsonb, asKysely } from '../db/unit-of-work.kysely.js';
import {
  ABANDONED_AFTER_SECONDS,
  type IdempotencyStore,
  type IdempotentRequest,
  type ReservationResult,
} from './idempotency-store.js';

const MAX_ATTEMPTS = 3;

function referencedIds(scope: string, body: unknown): string[] {
  const values = [scope, body];
  const ids = new Set<string>();
  while (values.length) {
    const value = values.pop();
    if (typeof value === 'string' && isUuid(value)) ids.add(value.toLowerCase());
    else if (value !== null && typeof value === 'object') {
      for (const property of Object.values(value)) values.push(property);
    }
  }
  return [...ids];
}

/**
 * Store in `compartido.idempotencia`. Reserving is atomic (INSERT … ON CONFLICT DO NOTHING):
 * when two retries arrive at once, only one runs the action and the other gets "in progress".
 */
export class PostgresIdempotencyStore implements IdempotencyStore {
  constructor(
    private readonly db: Kysely<SharedTables>,
    private readonly retentionHours: number,
    private readonly accounts?: AccountAccess,
  ) {}

  async reserve(request: IdempotentRequest, now: Date): Promise<ReservationResult> {
    for (let attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
      const result = await this.tryReserve(request, now);
      if (result) return result;
    }
    return { kind: 'in_progress' };
  }

  private async tryReserve(
    request: IdempotentRequest,
    now: Date,
  ): Promise<ReservationResult | null> {
    const expiresAt = new Date(now.getTime() + this.retentionHours * 3_600_000);
    const inserted = await this.db
      .insertInto('compartido.idempotencia')
      .values({
        alcance: request.scope,
        clave: request.key,
        metodo: request.method,
        ruta: request.path,
        huella: request.fingerprint,
        estado: 'en_curso',
        codigo_http: null,
        cuerpo_respuesta: null,
        creada_en: now,
        expira_en: expiresAt,
      })
      .onConflict((conflict) => conflict.columns(['alcance', 'clave']).doNothing())
      .returning('clave')
      .executeTakeFirst();
    if (inserted) return { kind: 'new' };

    const row = await this.db
      .selectFrom('compartido.idempotencia')
      .selectAll()
      .where('alcance', '=', request.scope)
      .where('clave', '=', request.key)
      .executeTakeFirst();
    if (!row) return null; // Released between the INSERT and the SELECT: try again.

    if (row.expira_en.getTime() <= now.getTime()) {
      return (await this.takeOver(request, now, expiresAt, row.creada_en, 'expired'))
        ? { kind: 'new' }
        : null;
    }
    if (row.huella !== request.fingerprint) return { kind: 'fingerprint_mismatch' };
    if (row.estado === 'completada' && row.codigo_http !== null) {
      return { kind: 'replay', httpStatus: row.codigo_http, body: row.cuerpo_respuesta };
    }
    const abandoned = now.getTime() - row.creada_en.getTime() > ABANDONED_AFTER_SECONDS * 1000;
    if (abandoned) {
      return (await this.takeOver(request, now, expiresAt, row.creada_en, 'abandoned'))
        ? { kind: 'new' }
        : { kind: 'in_progress' };
    }
    return { kind: 'in_progress' };
  }

  /** Compare-and-set: only one concurrent request manages to take over the reservation. */
  private async takeOver(
    request: IdempotentRequest,
    now: Date,
    expiresAt: Date,
    createdAtRead: Date,
    reason: 'expired' | 'abandoned',
  ): Promise<boolean> {
    let query = this.db
      .updateTable('compartido.idempotencia')
      .set({
        metodo: request.method,
        ruta: request.path,
        huella: request.fingerprint,
        estado: 'en_curso',
        codigo_http: null,
        cuerpo_respuesta: null,
        creada_en: now,
        expira_en: expiresAt,
      })
      .where('alcance', '=', request.scope)
      .where('clave', '=', request.key)
      // JS keeps milliseconds and Postgres microseconds: compare truncated to milliseconds.
      .where(sql<Date>`date_trunc('milliseconds', creada_en)`, '=', createdAtRead);
    if (reason === 'abandoned') {
      query = query.where('estado', '=', 'en_curso');
    }
    const result = await query.executeTakeFirst();
    return Number(result.numUpdatedRows) === 1;
  }

  async complete(scope: string, key: string, httpStatus: number, body: unknown): Promise<void> {
    const persist = async (db: Kysely<SharedTables>) => {
      await db
        .updateTable('compartido.idempotencia')
        .set({ estado: 'completada', codigo_http: httpStatus, cuerpo_respuesta: asJsonb(body) })
        .where('alcance', '=', scope)
        .where('clave', '=', key)
        .execute();
    };
    const ids = referencedIds(scope, body);
    const accounts = this.accounts;
    if (!accounts || !ids.length) return persist(this.db);
    await new KyselyUnitOfWork(this.db).run(async (tx) => {
      const db = asKysely<SharedTables>(tx);
      const states = await accounts.lockStates(tx, ids);
      // Never recreate a copy after erasure, even if another actor obtained the response earlier.
      if ([...states.values()].some((active) => !active)) {
        await db
          .deleteFrom('compartido.idempotencia')
          .where('alcance', '=', scope)
          .where('clave', '=', key)
          .execute();
        return;
      }
      await persist(db);
    });
  }

  async release(scope: string, key: string): Promise<void> {
    await this.db
      .deleteFrom('compartido.idempotencia')
      .where('alcance', '=', scope)
      .where('clave', '=', key)
      .where('estado', '=', 'en_curso')
      .execute();
  }

  /** Periodic cleanup (scheduled by the Lot B worker). */
  async deleteExpired(now: Date): Promise<number> {
    const result = await this.db
      .deleteFrom('compartido.idempotencia')
      .where('expira_en', '<', now)
      .executeTakeFirst();
    return Number(result.numDeletedRows);
  }
}
