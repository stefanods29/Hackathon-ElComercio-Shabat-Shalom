import type { DomainEvent } from '../../../shared/domain/domain-event.js';

export const IDENTITY_MODULE = 'identidad';
export const ZONE_CHANGED_EVENT = 'identidad.zona_cambiada';
export const RESIDENCE_CONFIRMED_EVENT = 'identidad.residencia_confirmada';
export const ACCOUNT_DELETED_EVENT = 'identidad.cuenta_borrada';
export const PRESENCE_CLEANUP_JOB = 'identidad.limpiar_presencias';

export function zoneChanged(
  userId: string,
  previousZoneId: string,
  zoneId: string,
  now: Date,
): DomainEvent {
  return {
    type: ZONE_CHANGED_EVENT,
    aggregateId: userId,
    occurredAt: now,
    payload: { zonaAnteriorId: previousZoneId, zonaId: zoneId },
  };
}

export function residenceConfirmed(
  userId: string,
  zoneId: string,
  level: number,
  method: 'presencia' | 'manual' | 'avales',
  now: Date,
): DomainEvent {
  return {
    type: RESIDENCE_CONFIRMED_EVENT,
    aggregateId: userId,
    occurredAt: now,
    payload: { zonaId: zoneId, nivel: level, metodo: method },
  };
}

export function accountDeleted(userId: string, now: Date): DomainEvent {
  return { type: ACCOUNT_DELETED_EVENT, aggregateId: userId, occurredAt: now, payload: {} };
}
