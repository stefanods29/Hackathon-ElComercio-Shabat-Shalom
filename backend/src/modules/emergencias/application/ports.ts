import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import type {
  Assignment,
  CriticalResource,
  DutyShift,
  EmergencyEvent,
  HelpRequest,
  OperationalGrant,
  OperationalRole,
  PrivateRequestDetails,
  RequestState,
  SupportGroup,
} from '../domain/emergency.js';

export interface GrantEvidence {
  readonly dniReviewedAt: Date;
  readonly trainedAt: Date;
  readonly confidentialityAt: Date;
  readonly reviewReference: string;
  readonly reviewedBy: string;
}
export interface RequestHistory {
  readonly from: RequestState | null;
  readonly to: RequestState;
  readonly role: string;
  readonly at: Date;
  readonly reason: string | null;
}
export interface AuditEntry {
  readonly id: string;
  readonly userId: string | null;
  readonly requestId: string | null;
  readonly role: string;
  readonly action: string;
  readonly occurredAt: Date;
}
export interface CellAggregate {
  readonly id: string;
  readonly zoneId: string;
  readonly cell: string;
  readonly need: string;
  readonly count: number;
  readonly updatedAt: Date;
}
export interface OfficialAlert {
  readonly externalId: string;
  readonly zoneId: string;
  readonly level: number;
  readonly issuedAt: Date;
}
export interface OfficialAlertSource {
  read(): Promise<readonly OfficialAlert[]>;
}
export const OFFICIAL_ALERT_SOURCE = Symbol('OFFICIAL_ALERT_SOURCE');

/** All methods use the caller's transaction. No adapter may read another module's tables. */
export interface EventStore {
  lockZone(tx: TransactionContext, zoneId: string): Promise<void>;
  find(tx: TransactionContext, id: string): Promise<EmergencyEvent | null>;
  current(tx: TransactionContext, zoneId: string): Promise<EmergencyEvent | null>;
  list(tx: TransactionContext, zoneId: string): Promise<EmergencyEvent[]>;
  insert(tx: TransactionContext, event: EmergencyEvent, actorId: string | null): Promise<void>;
  close(
    tx: TransactionContext,
    event: EmergencyEvent,
    now: Date,
    reason: string,
  ): Promise<EmergencyEvent>;
  closing(tx: TransactionContext): Promise<string[]>;
  anonymizeBatch(tx: TransactionContext, eventId: string, now: Date): Promise<boolean>;
  processedAlert(tx: TransactionContext, reference: string, now: Date): Promise<boolean>;
}
export const EVENT_STORE = Symbol('EVENT_STORE');
export interface OperationsStore {
  grants(tx: TransactionContext, zoneId: string, now: Date): Promise<OperationalGrant[]>;
  grant(tx: TransactionContext, id: string): Promise<OperationalGrant | null>;
  grantFor(
    tx: TransactionContext,
    userId: string,
    zoneId: string,
    role: OperationalRole,
  ): Promise<OperationalGrant | null>;
  saveGrant(
    tx: TransactionContext,
    grant: OperationalGrant,
    evidence: GrantEvidence,
  ): Promise<OperationalGrant>;
  revoke(tx: TransactionContext, grant: OperationalGrant, now: Date): Promise<OperationalGrant>;
  activeGrants(
    tx: TransactionContext,
    userId: string,
    role: OperationalRole,
    now: Date,
  ): Promise<number>;
  shifts(tx: TransactionContext, zoneId: string, now: Date): Promise<DutyShift[]>;
  shift(tx: TransactionContext, id: string): Promise<DutyShift | null>;
  insertShift(tx: TransactionContext, shift: DutyShift): Promise<DutyShift>;
  overlapsShift(tx: TransactionContext, shift: DutyShift): Promise<boolean>;
  endShift(tx: TransactionContext, shift: DutyShift, now: Date): Promise<DutyShift>;
  lockUser(tx: TransactionContext, userId: string): Promise<void>;
  finishAssignments(
    tx: TransactionContext,
    userId: string,
    now: Date,
    role?: 'coordinador' | 'brigadista',
  ): Promise<void>;
  groups(tx: TransactionContext, zoneId: string): Promise<SupportGroup[]>;
  group(tx: TransactionContext, id: string): Promise<SupportGroup | null>;
  saveGroup(tx: TransactionContext, group: SupportGroup): Promise<SupportGroup>;
  setSupportZones(tx: TransactionContext, zoneId: string, zones: readonly string[]): Promise<void>;
  supportZones(tx: TransactionContext, zoneId: string): Promise<string[]>;
  expireAssignments(tx: TransactionContext, now: Date): Promise<void>;
}
export const OPERATIONS_STORE = Symbol('OPERATIONS_STORE');
export interface RequestStore {
  find(tx: TransactionContext, id: string): Promise<HelpRequest | null>;
  insert(
    tx: TransactionContext,
    request: HelpRequest,
    details: PrivateRequestDetails,
  ): Promise<void>;
  list(
    tx: TransactionContext,
    filter: {
      ownerId?: string;
      zoneId?: string;
      operatorId?: string;
      now: Date;
      cursor?: string;
      limit: number;
    },
  ): Promise<HelpRequest[]>;
  details(tx: TransactionContext, id: string): Promise<PrivateRequestDetails | null>;
  assignments(tx: TransactionContext, id: string, now: Date): Promise<Assignment[]>;
  assign(tx: TransactionContext, assignment: Assignment, now: Date): Promise<void>;
  history(tx: TransactionContext, id: string): Promise<RequestHistory[]>;
  addHistory(
    tx: TransactionContext,
    id: string,
    entry: RequestHistory,
    actorId: string | null,
  ): Promise<void>;
  update(tx: TransactionContext, request: HelpRequest): Promise<void>;
  due(tx: TransactionContext, now: Date): Promise<string[]>;
  expired(tx: TransactionContext, now: Date): Promise<string[]>;
  wasEscalatedTo(tx: TransactionContext, id: string, userId: string): Promise<boolean>;
  recordEscalation(
    tx: TransactionContext,
    request: HelpRequest,
    userId: string | null,
    now: Date,
  ): Promise<void>;
  removePrivate(tx: TransactionContext, id: string): Promise<void>;
}
export const REQUEST_STORE = Symbol('REQUEST_STORE');
export interface ResourceStore {
  find(tx: TransactionContext, id: string): Promise<CriticalResource | null>;
  insert(tx: TransactionContext, resource: CriticalResource): Promise<void>;
  update(
    tx: TransactionContext,
    resource: CriticalResource,
    clearConfirmations: boolean,
  ): Promise<void>;
  confirm(tx: TransactionContext, id: string, userId: string, now: Date): Promise<void>;
  confirmationCount(tx: TransactionContext, id: string): Promise<number>;
  list(
    tx: TransactionContext,
    zoneId: string,
    cursor: string | undefined,
    limit: number,
  ): Promise<CriticalResource[]>;
  refreshAggregates(tx: TransactionContext, now: Date): Promise<void>;
  aggregates(tx: TransactionContext, zoneId: string): Promise<CellAggregate[]>;
}
export const RESOURCE_STORE = Symbol('RESOURCE_STORE');
export interface AuditStore {
  record(
    tx: TransactionContext,
    actorId: string | null,
    role: string,
    requestId: string | null,
    action: string,
    now: Date,
  ): Promise<void>;
  list(tx: TransactionContext, cursor: string | undefined, limit: number): Promise<AuditEntry[]>;
}
export const AUDIT_STORE = Symbol('AUDIT_STORE');
