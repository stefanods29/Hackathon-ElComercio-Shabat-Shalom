import { BusinessRuleViolation, VersionConflict } from '../../../shared/domain/errors.js';

export const REQUEST_STATES = [
  'enviado',
  'visto',
  'en_camino',
  'atendido',
  'derivado',
  'cerrado_sin_atender',
] as const;
export type RequestState = (typeof REQUEST_STATES)[number];
export const NEEDS = ['agua', 'alimentos', 'medicamentos', 'traslado', 'albergue', 'otro'] as const;
export type Need = (typeof NEEDS)[number];
export const PRIORITIES = ['alta', 'media', 'baja'] as const;
export type Priority = (typeof PRIORITIES)[number];
export const OPERATIONAL_ROLES = ['coordinador', 'brigadista', 'curador'] as const;
export type OperationalRole = (typeof OPERATIONAL_ROLES)[number];
export const RESOURCE_TYPES = [
  'agua',
  'alimentos',
  'medicamentos',
  'traslado',
  'albergue',
  'punto_encuentro',
] as const;
export type ResourceType = (typeof RESOURCE_TYPES)[number];
export type EventState = 'emergencia' | 'recuperacion' | 'normal';

export interface Coordinates {
  readonly lat: number;
  readonly lng: number;
}
export interface EmergencyEvent {
  readonly id: string;
  readonly zoneId: string;
  readonly level: number;
  readonly state: EventState;
  readonly version: number;
  readonly createdAt: Date;
  readonly closedAt: Date | null;
  readonly source: string;
  readonly externalId: string | null;
  readonly summary: Readonly<Record<string, unknown>> | null;
}
export interface HelpRequest {
  readonly id: string;
  readonly eventId: string;
  readonly zoneId: string;
  readonly ownerId: string | null;
  readonly need: Need;
  readonly priority: Priority;
  readonly state: RequestState;
  readonly version: number;
  readonly cell: string;
  readonly createdAt: Date;
  readonly expiresAt: Date;
  readonly seenAt: Date | null;
  readonly closedAt: Date | null;
  readonly escalateAt: Date | null;
  readonly escalationStage: number;
  readonly fingerprint: string;
  readonly anonymizedAt: Date | null;
}
export interface PrivateRequestDetails {
  readonly description: string;
  readonly location: Coordinates | null;
}
export interface Assignment {
  readonly id: string;
  readonly requestId: string;
  readonly userId: string;
  readonly role: 'coordinador' | 'brigadista';
  readonly expiresAt: Date;
}
export interface OperationalGrant {
  readonly id: string;
  readonly userId: string;
  readonly zoneId: string;
  readonly role: OperationalRole;
  readonly expiresAt: Date;
  readonly revokedAt: Date | null;
  readonly version: number;
}
export interface DutyShift {
  readonly id: string;
  readonly userId: string;
  readonly zoneId: string;
  readonly role: OperationalRole;
  readonly startsAt: Date;
  readonly endsAt: Date;
  readonly endedAt: Date | null;
  readonly version: number;
}
export interface SupportGroup {
  readonly id: string;
  readonly zoneId: string;
  readonly name: string;
  readonly verifiedAt: Date;
  readonly version: number;
  readonly members: readonly string[];
}
export interface CriticalResource {
  readonly id: string;
  readonly zoneId: string;
  readonly reporterId: string | null;
  readonly creationFingerprint: string;
  readonly type: ResourceType;
  readonly quantity: number;
  readonly cell: string;
  readonly reportedAt: Date;
  readonly staleAfterSeconds: number;
  readonly verification: 'sin_verificar' | 'confirmado' | 'verificado';
  readonly confirmations: number;
  readonly publicLabel: string | null;
  readonly sourceUrl: string | null;
  readonly official: boolean;
  readonly version: number;
}

const TRANSITIONS: Readonly<Record<RequestState, readonly RequestState[]>> = {
  enviado: ['visto'],
  visto: ['en_camino', 'derivado', 'cerrado_sin_atender'],
  en_camino: ['atendido'],
  atendido: [],
  derivado: [],
  cerrado_sin_atender: [],
};
export function isOpen(state: RequestState): boolean {
  return state === 'enviado' || state === 'visto' || state === 'en_camino';
}
export function assertVersion(expected: number, actual: number): void {
  if (expected !== actual) throw new VersionConflict(expected, actual);
}
export function transition(request: HelpRequest, target: RequestState, reason?: string): void {
  if (!TRANSITIONS[request.state].includes(target)) {
    throw new BusinessRuleViolation(
      'transicion_invalida',
      'Ese cambio no está permitido para el estado actual.',
      'conflict',
    );
  }
  if ((target === 'derivado' || target === 'cerrado_sin_atender') && !reason?.trim()) {
    throw new BusinessRuleViolation(
      'motivo_requerido',
      'Indica el motivo del cierre o la derivación.',
    );
  }
}
/** Server-owned cells are about one kilometre wide; client labels never define aggregation. */
export function publicCell(location: Coordinates): string {
  return `${Math.floor((location.lat + 90) * 100)}:${Math.floor((location.lng + 180) * 100)}`;
}
export function cellBounds(cell: string) {
  const [row = 0, column = 0] = cell.split(':').map(Number);
  const south = row / 100 - 90;
  const west = column / 100 - 180;
  return { sur: south, oeste: west, norte: south + 0.01, este: west + 0.01 };
}
export function requireFutureWindow(start: Date, end: Date, now: Date): void {
  if (
    end <= start ||
    end <= now ||
    end.getTime() - start.getTime() > 24 * 3600000 ||
    start.getTime() > now.getTime() + 30 * 86400000
  ) {
    throw new BusinessRuleViolation(
      'turno_invalido',
      'El turno debe durar como máximo 24 horas y comenzar en los próximos 30 días.',
    );
  }
}
