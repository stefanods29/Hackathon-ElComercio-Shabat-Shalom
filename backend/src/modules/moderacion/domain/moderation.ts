import type { ContentRef } from '../../../shared/moderation/content-moderation.js';

export const REPORT_REASONS = [
  'spam',
  'ofensivo',
  'informacion_falsa',
  'datos_personales',
  'peligroso',
  'otro',
] as const;
export type ReportReason = (typeof REPORT_REASONS)[number];
export const CASE_STATES = ['pendiente', 'resuelto'] as const;
export type CaseState = (typeof CASE_STATES)[number];
export const DECISIONS = ['publicar', 'ocultar', 'restaurar', 'descartar', 'sancionar'] as const;
export type Decision = (typeof DECISIONS)[number];
export const SUSPENSION_MS = 7 * 24 * 60 * 60 * 1000;

export interface ModerationCase {
  readonly id: string;
  readonly content: ContentRef;
  readonly ownerId: string | null;
  readonly state: CaseState;
  readonly reason: string;
  readonly lastDecision: Decision | null;
  readonly createdAt: Date;
  readonly updatedAt: Date;
  readonly firstReviewedAt: Date | null;
  readonly cursorDate: string;
}

export interface ReportData {
  readonly id: string;
  readonly content: ContentRef;
  readonly reason: ReportReason;
  readonly details: string | null;
}

export interface Report extends ReportData {
  readonly caseId: string;
  readonly reporterId: string;
  readonly createdAt: Date;
}

export interface CaseCursor {
  readonly createdAt: string;
  readonly id: string;
  readonly state: CaseState;
}
