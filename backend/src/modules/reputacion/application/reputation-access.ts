import type { ServiceForReputation } from '../../directorio/index.js';
import { BusinessRuleViolation, ResourceNotFound } from '../../../shared/domain/errors.js';
import type { ReputationActor } from './ports.js';

export function assertReputationLevel(actor: ReputationActor): void {
  if (actor.trustLevel < 1) {
    throw new BusinessRuleViolation(
      'nivel_de_confianza_insuficiente',
      'Primero confirma que vives en tu zona.',
      'forbidden',
      {
        nivelActual: actor.trustLevel,
        nivelRequerido: 1,
      },
    );
  }
}

export function reputationZone(actor: ReputationActor): string {
  assertReputationLevel(actor);
  if (!actor.zoneId)
    throw new BusinessRuleViolation('sin_zona', 'Primero elige tu zona.', 'forbidden');
  return actor.zoneId;
}

export function assertCanRate(
  service: ServiceForReputation | null,
  serviceId: string,
  actorId: string,
  zoneId: string,
): void {
  if (!service?.active) throw new ResourceNotFound('el servicio', serviceId);
  if (service.providerId === actorId) {
    throw new BusinessRuleViolation(
      'no_puedes_resenarte',
      'No puedes calificar tu propio servicio.',
      'forbidden',
    );
  }
  if (service.zoneId !== zoneId) {
    throw new BusinessRuleViolation(
      'fuera_de_tu_zona',
      'Solo puedes calificar servicios de tu zona.',
      'forbidden',
    );
  }
}
