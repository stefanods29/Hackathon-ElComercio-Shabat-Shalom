import { BusinessRuleViolation } from '../../../shared/domain/errors.js';
import type { DirectoryActor } from './ports.js';

export function requireProviderZone(actor: DirectoryActor): string {
  if (actor.trustLevel < 1) {
    throw new BusinessRuleViolation(
      'nivel_de_confianza_insuficiente',
      'Primero confirma que vives en tu zona.',
      'forbidden',
      { nivelActual: actor.trustLevel, nivelRequerido: 1 },
    );
  }
  if (!actor.zoneId) {
    throw new BusinessRuleViolation('sin_zona', 'Primero elige tu zona.', 'forbidden');
  }
  return actor.zoneId;
}
