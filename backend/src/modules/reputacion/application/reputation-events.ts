import type { DomainEvent } from '../../../shared/domain/domain-event.js';

export const REPUTATION_RECALCULATION_JOB = 'reputacion.recalculo_solicitado';
export const REPUTATION_AGGREGATES_EVENT = 'reputacion.agregados_recalculados';

/** Include with the domain change, in the same outbox transaction. */
export function recalculationRequested(serviceId: string, occurredAt: Date): DomainEvent {
  return {
    type: REPUTATION_RECALCULATION_JOB,
    aggregateId: serviceId,
    occurredAt,
    payload: { servicioId: serviceId },
  };
}
