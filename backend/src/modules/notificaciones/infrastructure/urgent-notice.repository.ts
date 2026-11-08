import { Inject, Injectable } from '@nestjs/common';
import { type Kysely, type RawBuilder, sql } from 'kysely';
import { KYSELY } from '../../../shared/db/connection.js';
import type {
  NoBackupReason,
  PendingUrgentNotice,
  SmsBudget,
  SmsCostReservation,
  SmsReservation,
  UrgentNoticeRecord,
  UrgentNoticeState,
  UrgentNoticeStore,
  UrgentNoticeSummary,
} from '../application/ports.js';

/** A notice gets at most this many SMS attempts, even if the review job keeps retrying. */
const MAX_SMS_ATTEMPTS = 3;

/** America/Lima day of an instant: spending rows and their caps follow the pilot's calendar. */
function limaDay(at: Date): RawBuilder<unknown> {
  return sql`(${at}::timestamptz AT TIME ZONE 'America/Lima')::date`;
}

function limaMonthStart(at: Date): RawBuilder<unknown> {
  return sql`date_trunc('month', ${at}::timestamptz AT TIME ZONE 'America/Lima')::date`;
}

@Injectable()
export class UrgentNoticeRepository implements UrgentNoticeStore {
  constructor(@Inject(KYSELY) private readonly db: Kysely<unknown>) {}

  async claim(input: {
    readonly avisoId: string;
    readonly usuarioId: string;
    readonly plantilla: string;
    readonly casoId: string | null;
    readonly fingerprint: string;
    readonly confirmBefore: Date;
  }): Promise<'created' | 'existing' | 'conflict'> {
    return this.db.transaction().execute(async (trx) => {
      const inserted = await sql`INSERT INTO notificaciones.avisos_urgentes
          (aviso_id, usuario_id, plantilla, caso_id, huella, confirmar_antes_de)
        VALUES (${input.avisoId}::uuid, ${input.usuarioId}::uuid, ${input.plantilla},
          ${input.casoId}::uuid, ${input.fingerprint}, ${input.confirmBefore}::timestamptz)
        ON CONFLICT DO NOTHING RETURNING aviso_id`.execute(trx);
      if (inserted.rows.length > 0) return 'created';
      const saved = await sql<{ huella: string }>`SELECT huella FROM notificaciones.avisos_urgentes
        WHERE aviso_id = ${input.avisoId}::uuid`.execute(trx);
      return saved.rows[0]?.huella === input.fingerprint ? 'existing' : 'conflict';
    });
  }

  async recordReach(avisoId: string, devices: number): Promise<void> {
    await sql`UPDATE notificaciones.avisos_urgentes SET dispositivos_alcanzados = ${devices}
      WHERE aviso_id = ${avisoId}::uuid`.execute(this.db);
  }

  async find(avisoId: string): Promise<UrgentNoticeRecord | null> {
    const result = await sql<{
      aviso_id: string;
      usuario_id: string;
      plantilla: string;
      caso_id: string | null;
      estado: UrgentNoticeState;
      confirmado_en: Date | null;
      sms_intentos: number;
    }>`SELECT aviso_id, usuario_id, plantilla, caso_id, estado, confirmado_en, sms_intentos
      FROM notificaciones.avisos_urgentes WHERE aviso_id = ${avisoId}::uuid`.execute(this.db);
    const row = result.rows[0];
    if (!row) return null;
    return {
      avisoId: row.aviso_id,
      usuarioId: row.usuario_id,
      plantilla: row.plantilla,
      casoId: row.caso_id,
      estado: row.estado,
      confirmadoEn: row.confirmado_en,
      smsIntentos: row.sms_intentos,
    };
  }

  async confirm(avisoId: string, usuarioId: string, now: Date): Promise<Date | null> {
    const result = await sql<{ confirmado_en: Date }>`UPDATE notificaciones.avisos_urgentes
      SET confirmado_en = coalesce(confirmado_en, ${now}::timestamptz),
        estado = CASE WHEN estado = 'esperando_confirmacion' THEN 'confirmado' ELSE estado END
      WHERE aviso_id = ${avisoId}::uuid AND usuario_id = ${usuarioId}::uuid
      RETURNING confirmado_en`.execute(this.db);
    return result.rows[0]?.confirmado_en ?? null;
  }

  async pendingFor(usuarioId: string, since: Date): Promise<PendingUrgentNotice[]> {
    const result = await sql<{
      aviso_id: string;
      plantilla: string;
      caso_id: string | null;
      creado_en: Date;
    }>`SELECT aviso_id, plantilla, caso_id, creado_en FROM notificaciones.avisos_urgentes
      WHERE usuario_id = ${usuarioId}::uuid AND confirmado_en IS NULL
        AND creado_en >= ${since}::timestamptz
      ORDER BY creado_en DESC LIMIT 20`.execute(this.db);
    return result.rows.map((row) => ({
      avisoId: row.aviso_id,
      plantilla: row.plantilla,
      casoId: row.caso_id,
      creadoEn: row.creado_en,
    }));
  }

  async reserveSms(
    avisoId: string,
    budget: SmsBudget,
    checks: { readonly providerEnabled: boolean; readonly hasPhone: boolean },
  ): Promise<SmsReservation> {
    return this.db.transaction().execute(async (trx) => {
      const locked = await sql<{
        estado: UrgentNoticeState;
        confirmado_en: Date | null;
        sms_intentos: number;
      }>`SELECT estado, confirmado_en, sms_intentos FROM notificaciones.avisos_urgentes
        WHERE aviso_id = ${avisoId}::uuid FOR UPDATE`.execute(trx);
      const notice = locked.rows[0];
      if (!notice) return { kind: 'nothing_to_do' } as const;
      if (notice.confirmado_en) {
        await sql`UPDATE notificaciones.avisos_urgentes SET estado = 'confirmado'
          WHERE aviso_id = ${avisoId}::uuid AND estado = 'esperando_confirmacion'`.execute(trx);
        return { kind: 'nothing_to_do' } as const;
      }
      // `sms_enviando` means an earlier attempt stopped between reserving and recording.
      if (notice.estado !== 'esperando_confirmacion' && notice.estado !== 'sms_enviando') {
        return { kind: 'nothing_to_do' } as const;
      }
      const close = async (reason: NoBackupReason): Promise<SmsReservation> => {
        await sql`UPDATE notificaciones.avisos_urgentes SET estado = 'sin_respaldo', motivo = ${reason}
          WHERE aviso_id = ${avisoId}::uuid`.execute(trx);
        return { kind: 'closed', reason };
      };
      if (!checks.providerEnabled) return close('sin_proveedor');
      if (!checks.hasPhone) return close('sin_telefono');
      if (notice.sms_intentos >= MAX_SMS_ATTEMPTS) return close('sms_fallido');

      // Locking the day's row serializes concurrent reviews, so two of them cannot both pass the cap.
      await sql`INSERT INTO notificaciones.gasto_sms (dia) VALUES (${limaDay(budget.now)})
        ON CONFLICT (dia) DO NOTHING`.execute(trx);
      const today = await sql<{ centavos: number }>`SELECT centavos FROM notificaciones.gasto_sms
        WHERE dia = ${limaDay(budget.now)} FOR UPDATE`.execute(trx);
      const month = await sql<{ total: number }>`SELECT coalesce(sum(centavos), 0)::int AS total
        FROM notificaciones.gasto_sms WHERE dia >= ${limaMonthStart(budget.now)}`.execute(trx);
      const dayTotal = today.rows[0]?.centavos ?? 0;
      const monthTotal = month.rows[0]?.total ?? 0;
      if (
        dayTotal + budget.costCents > budget.dailyCapCents ||
        monthTotal + budget.costCents > budget.monthlyCapCents
      ) {
        return close('tope_de_gasto');
      }
      await sql`UPDATE notificaciones.gasto_sms
        SET centavos = centavos + ${budget.costCents}, mensajes = mensajes + 1
        WHERE dia = ${limaDay(budget.now)}`.execute(trx);
      await sql`UPDATE notificaciones.avisos_urgentes
        SET estado = 'sms_enviando', sms_intentos = sms_intentos + 1,
          costo_centavos = costo_centavos + ${budget.costCents}
        WHERE aviso_id = ${avisoId}::uuid`.execute(trx);
      return { kind: 'reserved', costCents: budget.costCents } as const;
    });
  }

  async markSmsSent(avisoId: string, sentAt: Date, reservation: SmsCostReservation): Promise<void> {
    const difference = reservation.actualCents - reservation.reservedCents;
    await this.db.transaction().execute(async (trx) => {
      await sql`UPDATE notificaciones.avisos_urgentes
        SET estado = 'sms_enviado', sms_enviado_en = ${sentAt}::timestamptz,
          costo_centavos = greatest(costo_centavos + ${difference}, 0)
        WHERE aviso_id = ${avisoId}::uuid AND estado = 'sms_enviando'`.execute(trx);
      if (difference !== 0) {
        await sql`UPDATE notificaciones.gasto_sms
          SET centavos = greatest(centavos + ${difference}, 0)
          WHERE dia = ${limaDay(reservation.reservedAt)}`.execute(trx);
      }
    });
  }

  async releaseSms(
    avisoId: string,
    reservation: Omit<SmsCostReservation, 'actualCents'>,
    closeAs?: NoBackupReason,
  ): Promise<void> {
    await this.db.transaction().execute(async (trx) => {
      const released = await sql`UPDATE notificaciones.avisos_urgentes
        SET costo_centavos = greatest(costo_centavos - ${reservation.reservedCents}, 0),
          estado = ${closeAs ? 'sin_respaldo' : 'esperando_confirmacion'},
          motivo = ${closeAs ?? null}
        WHERE aviso_id = ${avisoId}::uuid AND estado = 'sms_enviando'
        RETURNING aviso_id`.execute(trx);
      if (released.rows.length === 0) return;
      await sql`UPDATE notificaciones.gasto_sms
        SET centavos = greatest(centavos - ${reservation.reservedCents}, 0),
          mensajes = greatest(mensajes - 1, 0)
        WHERE dia = ${limaDay(reservation.reservedAt)}`.execute(trx);
    });
  }

  async summary(since: Date, until: Date, now: Date): Promise<UrgentNoticeSummary> {
    const totals = await sql<{
      total: number;
      confirmados: number;
      sin_confirmar: number;
      sms_enviados: number;
      tope_de_gasto: number;
      sin_proveedor: number;
      sin_telefono: number;
      sms_fallido: number;
      p50: number | null;
      p95: number | null;
    }>`SELECT count(*)::int AS total,
        count(*) FILTER (WHERE confirmado_en IS NOT NULL)::int AS confirmados,
        count(*) FILTER (WHERE confirmado_en IS NULL)::int AS sin_confirmar,
        count(*) FILTER (WHERE estado = 'sms_enviado')::int AS sms_enviados,
        count(*) FILTER (WHERE motivo = 'tope_de_gasto')::int AS tope_de_gasto,
        count(*) FILTER (WHERE motivo = 'sin_proveedor')::int AS sin_proveedor,
        count(*) FILTER (WHERE motivo = 'sin_telefono')::int AS sin_telefono,
        count(*) FILTER (WHERE motivo = 'sms_fallido')::int AS sms_fallido,
        percentile_cont(0.5) WITHIN GROUP (
          ORDER BY extract(epoch FROM confirmado_en - creado_en)
        )::float8 AS p50,
        percentile_cont(0.95) WITHIN GROUP (
          ORDER BY extract(epoch FROM confirmado_en - creado_en)
        )::float8 AS p95
      FROM notificaciones.avisos_urgentes
      WHERE creado_en >= ${since}::timestamptz AND creado_en < ${until}::timestamptz`.execute(
      this.db,
    );
    const spending = await sql<{ hoy: number; mes: number }>`SELECT
        coalesce(sum(centavos) FILTER (WHERE dia = ${limaDay(now)}), 0)::int AS hoy,
        coalesce(sum(centavos), 0)::int AS mes
      FROM notificaciones.gasto_sms WHERE dia >= ${limaMonthStart(now)}`.execute(this.db);
    const row = totals.rows[0];
    const money = spending.rows[0];
    return {
      total: row?.total ?? 0,
      confirmados: row?.confirmados ?? 0,
      sinConfirmar: row?.sin_confirmar ?? 0,
      smsEnviados: row?.sms_enviados ?? 0,
      sinRespaldo: {
        tope_de_gasto: row?.tope_de_gasto ?? 0,
        sin_proveedor: row?.sin_proveedor ?? 0,
        sin_telefono: row?.sin_telefono ?? 0,
        sms_fallido: row?.sms_fallido ?? 0,
      },
      confirmacionSegundos: {
        p50: row?.p50 === null || row?.p50 === undefined ? null : Math.round(row.p50),
        p95: row?.p95 === null || row?.p95 === undefined ? null : Math.round(row.p95),
      },
      gasto: { hoyCentavos: money?.hoy ?? 0, mesCentavos: money?.mes ?? 0 },
    };
  }
}
