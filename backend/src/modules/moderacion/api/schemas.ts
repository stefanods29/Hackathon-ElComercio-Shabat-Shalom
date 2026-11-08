import { z } from 'zod';
import { CONTENT_TYPES } from '../../../shared/moderation/content-moderation.js';
import {
  CASE_STATES,
  DECISIONS,
  type ModerationCase,
  type Report,
  REPORT_REASONS,
} from '../domain/moderation.js';

export const reportSchema = z.strictObject({
  id: z.uuid({ version: 'v7' }),
  tipoContenido: z.enum(CONTENT_TYPES),
  contenidoId: z.uuid(),
  motivo: z.enum(REPORT_REASONS),
  detalle: z.string().trim().max(500).optional(),
});

export const caseIdSchema = z.uuid();
export const decisionSchema = z.strictObject({
  accion: z.enum(DECISIONS),
  motivo: z.string().trim().min(1).max(500),
});
export const queueSchema = z.strictObject({
  estado: z.enum(CASE_STATES).default('pendiente'),
  cursor: z.string().min(1).max(256).optional(),
  limite: z.coerce.number().int().min(1).max(50).default(20),
});
export const metricsSchema = z.strictObject({
  desde: z.iso.datetime({ offset: true }).optional(),
  hasta: z.iso.datetime({ offset: true }).optional(),
});

export type ReportDto = z.infer<typeof reportSchema>;
export type DecisionDto = z.infer<typeof decisionSchema>;
export type QueueDto = z.infer<typeof queueSchema>;
export type MetricsDto = z.infer<typeof metricsSchema>;

export function toReport(report: Report) {
  return {
    id: report.id,
    casoId: report.caseId,
    tipoContenido: report.content.type,
    contenidoId: report.content.id,
    motivo: report.reason,
    creadaEn: report.createdAt.toISOString(),
  };
}

export function toCase(item: ModerationCase) {
  return {
    id: item.id,
    tipoContenido: item.content.type,
    contenidoId: item.content.id,
    estado: item.state,
    motivo: item.reason,
    ultimaAccion: item.lastDecision,
    creadoEn: item.createdAt.toISOString(),
    actualizadoEn: item.updatedAt.toISOString(),
    primeraRevisionEn: item.firstReviewedAt?.toISOString() ?? null,
  };
}
