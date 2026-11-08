import { Inject, Injectable } from '@nestjs/common';
import { type Kysely, sql } from 'kysely';
import { z } from 'zod';
import { KYSELY } from '../db/connection.js';
import type { SharedTables } from '../db/shared-tables.js';
import { asJsonb } from '../db/unit-of-work.kysely.js';
import { CLOCK, type Clock } from '../domain/clock.js';

const MAX_COUNT = 100_000;
/** An action may wait offline for weeks before "Enviado". */
const MAX_WAIT_SECONDS = 90 * 24 * 60 * 60;
const MAX_SINCE_SYNC_SECONDS = 10 * 365 * 24 * 60 * 60;
const MAX_REJECTION_CODES = 20;
/** Days of the summary in `GET /v1/operacion/metricas`, today included. */
export const SYNC_SUMMARY_DAYS = 7;
const DAY_MS = 24 * 60 * 60 * 1000;

const count = z.number().int().min(0).max(MAX_COUNT);
const waitSeconds = z.number().int().min(0).max(MAX_WAIT_SECONDS).nullable();

/**
 * Body of `POST /v1/telemetria/sincronizacion`: aggregated counters of one phone since its last
 * report. Strict, so a field outside the contract (a phone number, an id, a location) answers 400
 * `validacion` and nothing is stored.
 */
export const syncTelemetrySchema = z
  .strictObject({
    versionApp: z.string().regex(/^[0-9A-Za-z.+-]{1,32}$/),
    sistema: z.enum(['android', 'ios']),
    periodoInicio: z.iso.datetime({ offset: true }),
    periodoFin: z.iso.datetime({ offset: true }),
    colaPendientes: count,
    enviosConfirmados: count,
    tiempoHastaEnviadoP50Segundos: waitSeconds,
    tiempoHastaEnviadoP95Segundos: waitSeconds,
    rechazosPermanentes: z.record(
      z.string().regex(/^[a-z0-9_]{1,64}$/),
      z.number().int().min(1).max(MAX_COUNT),
    ),
    segundosDesdeUltimaSincronizacion: z
      .number()
      .int()
      .min(0)
      .max(MAX_SINCE_SYNC_SECONDS)
      .nullable(),
    erroresDeConexion: count,
  })
  .superRefine((report, ctx) => {
    if (Date.parse(report.periodoFin) < Date.parse(report.periodoInicio)) {
      ctx.addIssue({
        code: 'custom',
        path: ['periodoFin'],
        message: 'periodoFin no puede ser anterior a periodoInicio',
      });
    }
    const p50 = report.tiempoHastaEnviadoP50Segundos;
    const p95 = report.tiempoHastaEnviadoP95Segundos;
    if (p50 !== null && p95 !== null && p50 > p95) {
      ctx.addIssue({
        code: 'custom',
        path: ['tiempoHastaEnviadoP50Segundos'],
        message: 'el p50 no puede superar al p95',
      });
    }
    if (Object.keys(report.rechazosPermanentes).length > MAX_REJECTION_CODES) {
      ctx.addIssue({
        code: 'custom',
        path: ['rechazosPermanentes'],
        message: `como máximo ${MAX_REJECTION_CODES} códigos`,
      });
    }
  });

export type SyncTelemetryReport = z.infer<typeof syncTelemetrySchema>;

/** Section `sincronizacion` of the operational metrics: no neighbor and no device. */
export interface SyncSummary {
  desde: string;
  reportes: number;
  enviosConfirmados: number;
  colaPendientesP95: number | null;
  tiempoHastaEnviadoP50Segundos: number | null;
  tiempoHastaEnviadoP95Segundos: number | null;
  rechazosPermanentes: Record<string, number>;
  segundosDesdeUltimaSincronizacionP95: number | null;
  erroresDeConexion: number;
}

/** UTC calendar day (`YYYY-MM-DD`): the only time a stored report keeps. */
export function utcDay(date: Date): string {
  return date.toISOString().slice(0, 10);
}

@Injectable()
export class SyncTelemetry {
  constructor(
    @Inject(KYSELY) private readonly db: Kysely<SharedTables>,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  /** Stores the counters without the neighbor, the device, the exact time or the exact period. */
  async record(report: SyncTelemetryReport): Promise<{ recibidoEl: string }> {
    const receivedOn = utcDay(this.clock.now());
    const periodMinutes = Math.round(
      (Date.parse(report.periodoFin) - Date.parse(report.periodoInicio)) / 60_000,
    );
    await this.db
      .insertInto('compartido.telemetria_sincronizacion')
      .values({
        recibido_el: receivedOn,
        version_app: report.versionApp,
        sistema: report.sistema,
        duracion_periodo_minutos: periodMinutes,
        cola_pendientes: report.colaPendientes,
        envios_confirmados: report.enviosConfirmados,
        tiempo_hasta_enviado_p50_segundos: report.tiempoHastaEnviadoP50Segundos,
        tiempo_hasta_enviado_p95_segundos: report.tiempoHastaEnviadoP95Segundos,
        rechazos_permanentes: asJsonb(report.rechazosPermanentes),
        segundos_desde_ultima_sincronizacion: report.segundosDesdeUltimaSincronizacion,
        errores_de_conexion: report.erroresDeConexion,
      })
      .execute();
    return { recibidoEl: receivedOn };
  }

  /**
   * Reports of the last [SYNC_SUMMARY_DAYS] days. The percentiles are computed over the values of
   * each report (for example, the p95 of every phone's p95), enough to spot a stuck queue.
   */
  async summary(): Promise<SyncSummary> {
    const since = utcDay(new Date(this.clock.now().getTime() - (SYNC_SUMMARY_DAYS - 1) * DAY_MS));
    const [totals, rejections] = await Promise.all([
      sql<{
        reports: number;
        sent: number;
        connectionErrors: number;
        queueP95: number | null;
        sentP50: number | null;
        sentP95: number | null;
        sinceSyncP95: number | null;
      }>`
        SELECT count(*)::int AS reports,
          coalesce(sum(envios_confirmados), 0)::int AS sent,
          coalesce(sum(errores_de_conexion), 0)::int AS "connectionErrors",
          percentile_cont(0.95) WITHIN GROUP (ORDER BY cola_pendientes) AS "queueP95",
          percentile_cont(0.5) WITHIN GROUP (ORDER BY tiempo_hasta_enviado_p50_segundos) AS "sentP50",
          percentile_cont(0.95) WITHIN GROUP (ORDER BY tiempo_hasta_enviado_p95_segundos) AS "sentP95",
          percentile_cont(0.95) WITHIN GROUP (ORDER BY segundos_desde_ultima_sincronizacion)
            AS "sinceSyncP95"
        FROM compartido.telemetria_sincronizacion
        WHERE recibido_el >= ${since}::date
      `.execute(this.db),
      sql<{ code: string; total: number }>`
        SELECT r.codigo AS code, sum(r.cantidad::int)::int AS total
        FROM compartido.telemetria_sincronizacion t
        CROSS JOIN LATERAL jsonb_each_text(t.rechazos_permanentes) AS r(codigo, cantidad)
        WHERE t.recibido_el >= ${since}::date
        GROUP BY r.codigo
        ORDER BY r.codigo
      `.execute(this.db),
    ]);
    const row = totals.rows[0]!;
    return {
      desde: since,
      reportes: row.reports,
      enviosConfirmados: row.sent,
      colaPendientesP95: row.queueP95,
      tiempoHastaEnviadoP50Segundos: row.sentP50,
      tiempoHastaEnviadoP95Segundos: row.sentP95,
      rechazosPermanentes: Object.fromEntries(
        rejections.rows.map((rejection) => [rejection.code, rejection.total]),
      ),
      segundosDesdeUltimaSincronizacionP95: row.sinceSyncP95,
      erroresDeConexion: row.connectionErrors,
    };
  }
}
