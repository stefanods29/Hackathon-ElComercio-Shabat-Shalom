import { Inject, Injectable } from '@nestjs/common';
import { type Kysely, sql } from 'kysely';
import { KYSELY } from '../../../shared/db/connection.js';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import { asKysely } from '../../../shared/db/unit-of-work.kysely.js';
import type {
  ContentRef,
  ContentType,
  VisibilityEvent,
} from '../../../shared/moderation/content-moderation.js';
import type {
  ModerationMetrics,
  ModerationStore,
  VisibilityPosition,
} from '../application/ports.js';
import type {
  CaseCursor,
  CaseState,
  Decision,
  ModerationCase,
  Report,
  ReportData,
  ReportReason,
} from '../domain/moderation.js';
import type { ScreeningFlag } from '../domain/screening.js';

interface CaseRow {
  id: string;
  tipo_contenido: ContentType;
  contenido_id: string;
  autor_id: string | null;
  estado: CaseState;
  motivo: string;
  ultima_accion: Decision | null;
  creado_en: Date;
  actualizado_en: Date;
  primera_revision_en: Date | null;
  posicion: string;
}

const cursorPosition = sql`to_char(creado_en AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS posicion`;

function toCase(row: CaseRow): ModerationCase {
  return {
    id: row.id,
    content: { type: row.tipo_contenido, id: row.contenido_id },
    ownerId: row.autor_id,
    state: row.estado,
    reason: row.motivo,
    lastDecision: row.ultima_accion,
    createdAt: row.creado_en,
    updatedAt: row.actualizado_en,
    firstReviewedAt: row.primera_revision_en,
    cursorDate: row.posicion,
  };
}

@Injectable()
export class KyselyModerationStore implements ModerationStore {
  constructor(@Inject(KYSELY) private readonly db: Kysely<unknown>) {}

  private async lock(tx: TransactionContext, key: string, shared = false): Promise<void> {
    const take = shared ? sql`pg_advisory_xact_lock_shared` : sql`pg_advisory_xact_lock`;
    await sql`SELECT ${take}(hashtextextended(${key}, 0))`.execute(asKysely(tx));
  }

  lockContent(tx: TransactionContext, ref: ContentRef): Promise<void> {
    return this.lock(tx, `moderacion:contenido:${ref.type}:${ref.id}`);
  }

  lockReport(tx: TransactionContext, id: string): Promise<void> {
    return this.lock(tx, `moderacion:denuncia:${id}`);
  }

  async findCase(tx: TransactionContext, id: string): Promise<ModerationCase | null> {
    const { rows } = await sql<CaseRow>`
      SELECT *, ${cursorPosition} FROM moderacion.casos WHERE id = ${id}
    `.execute(asKysely(tx));
    return rows[0] ? toCase(rows[0]) : null;
  }

  async caseForContent(tx: TransactionContext, ref: ContentRef): Promise<ModerationCase | null> {
    const { rows } = await sql<CaseRow>`
      SELECT *, ${cursorPosition} FROM moderacion.casos
      WHERE tipo_contenido = ${ref.type} AND contenido_id = ${ref.id}
    `.execute(asKysely(tx));
    return rows[0] ? toCase(rows[0]) : null;
  }

  async openCase(
    tx: TransactionContext,
    ref: ContentRef,
    ownerId: string,
    reason: string,
    now: Date,
    reopen: boolean,
  ): Promise<ModerationCase> {
    const conflict = reopen
      ? sql`DO UPDATE SET estado = 'pendiente', actualizado_en = EXCLUDED.actualizado_en,
          autor_id = COALESCE(caso.autor_id, EXCLUDED.autor_id),
          motivo = CASE WHEN caso.estado = 'resuelto' THEN EXCLUDED.motivo ELSE caso.motivo END`
      : sql`DO NOTHING`;
    await sql`
      INSERT INTO moderacion.casos AS caso (tipo_contenido, contenido_id, autor_id, estado, motivo, creado_en, actualizado_en)
      VALUES (${ref.type}, ${ref.id}, ${ownerId}, 'pendiente', ${reason}, ${now}, ${now})
      ON CONFLICT (tipo_contenido, contenido_id) ${conflict}
    `.execute(asKysely(tx));
    const result = await this.caseForContent(tx, ref);
    if (!result) throw new Error('No se pudo abrir el caso.');
    return result;
  }

  async findReport(tx: TransactionContext, id: string): Promise<Report | null> {
    const { rows } = await sql<{
      id: string;
      caso_id: string;
      denunciante_id: string;
      tipo_contenido: ContentType;
      contenido_id: string;
      motivo: ReportReason;
      detalle: string | null;
      creada_en: Date;
    }>`
      SELECT d.id, d.caso_id, d.denunciante_id, d.motivo, d.detalle, d.creada_en, c.tipo_contenido, c.contenido_id
      FROM moderacion.denuncias d JOIN moderacion.casos c ON c.id = d.caso_id WHERE d.id = ${id}
    `.execute(asKysely(tx));
    const row = rows[0];
    return row
      ? {
          id: row.id,
          caseId: row.caso_id,
          reporterId: row.denunciante_id,
          content: { type: row.tipo_contenido, id: row.contenido_id },
          reason: row.motivo,
          details: row.detalle,
          createdAt: row.creada_en,
        }
      : null;
  }

  async saveReport(
    tx: TransactionContext,
    report: ReportData,
    reporterId: string,
    caseId: string,
    now: Date,
  ): Promise<Report> {
    await sql`
      INSERT INTO moderacion.denuncias (id, caso_id, denunciante_id, motivo, detalle, creada_en)
      VALUES (${report.id}, ${caseId}, ${reporterId}, ${report.reason}, ${report.details}, ${now})
    `.execute(asKysely(tx));
    return { ...report, caseId, reporterId, createdAt: now };
  }

  async markReportScreened(
    tx: TransactionContext,
    id: string,
    flag: ScreeningFlag | null,
  ): Promise<void> {
    await sql`UPDATE moderacion.denuncias SET senal = ${flag ?? 'revision_humana'} WHERE id = ${id}`.execute(
      asKysely(tx),
    );
  }

  async list(state: CaseState, limit: number, cursor?: CaseCursor): Promise<ModerationCase[]> {
    const after = cursor
      ? sql`AND (creado_en, id) > (${cursor.createdAt}::timestamptz, ${cursor.id}::uuid)`
      : sql``;
    const { rows } = await sql<CaseRow>`
      SELECT *, ${cursorPosition} FROM moderacion.casos WHERE estado = ${state} ${after}
      ORDER BY creado_en, id LIMIT ${limit}
    `.execute(this.db);
    return rows.map(toCase);
  }

  async resolve(
    tx: TransactionContext,
    caseId: string,
    actorId: string,
    action: Decision,
    reason: string,
    now: Date,
  ) {
    const db = asKysely(tx);
    const decision = await sql<{ id: string }>`
      INSERT INTO moderacion.decisiones (caso_id, moderador_id, accion, motivo, decidida_en)
      VALUES (${caseId}, ${actorId}, ${action}, ${reason}, ${now}) RETURNING id
    `.execute(db);
    const result = await sql<CaseRow>`
      UPDATE moderacion.casos
      SET estado = 'resuelto', ultima_accion = ${action}, actualizado_en = ${now},
        primera_revision_en = COALESCE(primera_revision_en, GREATEST(creado_en, ${now}))
      WHERE id = ${caseId} RETURNING *, ${cursorPosition}
    `.execute(db);
    return { moderationCase: toCase(result.rows[0]!), decisionId: decision.rows[0]!.id };
  }

  async isSuspended(userId: string, now: Date, tx?: TransactionContext): Promise<boolean> {
    if (tx) await this.lock(tx, `moderacion:sancion:${userId}`, true);
    const { rows } = await sql<{ suspended: boolean }>`
      SELECT EXISTS (SELECT 1 FROM moderacion.sanciones
        WHERE usuario_id = ${userId} AND desde <= ${now} AND hasta > ${now}) AS suspended
    `.execute(tx ? asKysely(tx) : this.db);
    return rows[0]?.suspended ?? false;
  }

  async suspend(
    tx: TransactionContext,
    userId: string,
    decisionId: string,
    start: Date,
    end: Date,
  ): Promise<void> {
    await this.lock(tx, `moderacion:sancion:${userId}`);
    await sql`
      INSERT INTO moderacion.sanciones (usuario_id, decision_id, desde, hasta)
      VALUES (${userId}, ${decisionId}, ${start}, ${end})
    `.execute(asKysely(tx));
  }

  async visibility(tx: TransactionContext, ref: ContentRef): Promise<VisibilityPosition | null> {
    const { rows } = await sql<{
      evento: VisibilityEvent;
      ocurrido_en: Date;
      aplicado_en: Date | null;
    }>`
      SELECT evento, ocurrido_en, aplicado_en FROM moderacion.visibilidad
      WHERE tipo_contenido = ${ref.type} AND contenido_id = ${ref.id}
    `.execute(asKysely(tx));
    const row = rows[0];
    return row ? { event: row.evento, at: row.ocurrido_en, appliedAt: row.aplicado_en } : null;
  }

  async scheduleVisibility(
    tx: TransactionContext,
    ref: ContentRef,
    event: VisibilityEvent,
    at: Date,
  ): Promise<void> {
    await sql`
      INSERT INTO moderacion.visibilidad (tipo_contenido, contenido_id, evento, ocurrido_en)
      VALUES (${ref.type}, ${ref.id}, ${event}, ${at})
      ON CONFLICT (tipo_contenido, contenido_id) DO UPDATE
      SET evento = EXCLUDED.evento, ocurrido_en = EXCLUDED.ocurrido_en, aplicado_en = NULL
    `.execute(asKysely(tx));
  }

  async markVisibilityApplied(tx: TransactionContext, ref: ContentRef, now: Date): Promise<void> {
    await sql`
      UPDATE moderacion.visibilidad SET aplicado_en = ${now}
      WHERE tipo_contenido = ${ref.type} AND contenido_id = ${ref.id}
    `.execute(asKysely(tx));
  }

  async metrics(from: Date, until: Date): Promise<ModerationMetrics> {
    const { rows } = await sql<{ total: number; pendientes: number; p90: number | null }>`
      SELECT count(*)::int AS total, count(*) FILTER (WHERE estado = 'pendiente')::int AS pendientes,
        ceil(percentile_cont(0.9) WITHIN GROUP (ORDER BY extract(epoch FROM (primera_revision_en - creado_en))))::int AS p90
      FROM moderacion.casos WHERE creado_en >= ${from} AND creado_en < ${until}
    `.execute(this.db);
    return { total: rows[0]!.total, pending: rows[0]!.pendientes, p90Seconds: rows[0]!.p90 };
  }
}
