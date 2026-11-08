import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import type { ContentRef, VisibilityEvent } from '../../../shared/moderation/content-moderation.js';
import type {
  CaseCursor,
  CaseState,
  Decision,
  ModerationCase,
  Report,
  ReportData,
} from '../domain/moderation.js';
import type { ImageScreening, ScreeningFlag } from '../domain/screening.js';

export const MODERATION_STORE = Symbol('MODERATION_STORE');
export const IMAGE_MODERATION = Symbol('IMAGE_MODERATION');

export interface ImageModeration {
  /** File IDs refer to private assets, never a supplied URL. Missing scans cannot auto-approve. */
  inspect(fileId: string): Promise<ImageScreening>;
}

export interface VisibilityPosition {
  readonly event: VisibilityEvent;
  readonly at: Date;
  readonly appliedAt: Date | null;
}

export interface ModerationMetrics {
  readonly total: number;
  readonly pending: number;
  readonly p90Seconds: number | null;
}

export interface ModerationStore {
  lockContent(tx: TransactionContext, ref: ContentRef): Promise<void>;
  lockReport(tx: TransactionContext, id: string): Promise<void>;
  findCase(tx: TransactionContext, id: string): Promise<ModerationCase | null>;
  caseForContent(tx: TransactionContext, ref: ContentRef): Promise<ModerationCase | null>;
  openCase(
    tx: TransactionContext,
    ref: ContentRef,
    ownerId: string,
    reason: string,
    now: Date,
    reopen: boolean,
  ): Promise<ModerationCase>;
  findReport(tx: TransactionContext, id: string): Promise<Report | null>;
  saveReport(
    tx: TransactionContext,
    report: ReportData,
    reporterId: string,
    caseId: string,
    now: Date,
  ): Promise<Report>;
  markReportScreened(tx: TransactionContext, id: string, flag: ScreeningFlag | null): Promise<void>;
  list(state: CaseState, limit: number, cursor?: CaseCursor): Promise<ModerationCase[]>;
  resolve(
    tx: TransactionContext,
    caseId: string,
    actorId: string,
    action: Decision,
    reason: string,
    now: Date,
  ): Promise<{ moderationCase: ModerationCase; decisionId: string }>;
  isSuspended(userId: string, now: Date, tx?: TransactionContext): Promise<boolean>;
  suspend(
    tx: TransactionContext,
    userId: string,
    decisionId: string,
    start: Date,
    end: Date,
  ): Promise<void>;
  visibility(tx: TransactionContext, ref: ContentRef): Promise<VisibilityPosition | null>;
  scheduleVisibility(
    tx: TransactionContext,
    ref: ContentRef,
    event: VisibilityEvent,
    at: Date,
  ): Promise<void>;
  markVisibilityApplied(tx: TransactionContext, ref: ContentRef, now: Date): Promise<void>;
  metrics(from: Date, until: Date): Promise<ModerationMetrics>;
}
