import { BusinessRuleViolation } from '../../../shared/domain/errors.js';

const DAY_MS = 86_400_000;
const limaDate = new Intl.DateTimeFormat('en-CA', {
  calendar: 'gregory',
  numberingSystem: 'latn',
  timeZone: 'America/Lima',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
});

export const PRESENCE_WINDOW_DAYS = 14;
export const PRESENCE_RETENTION_DAYS = 30;
export const REQUIRED_PRESENCE_DAYS = 3;
export const REQUIRED_ENDORSEMENTS = 2;

export function residenceDay(at: Date): string {
  const parts = limaDate.formatToParts(at);
  const part = (type: 'year' | 'month' | 'day') =>
    parts.find((entry) => entry.type === type)!.value;
  return `${part('year')}-${part('month')}-${part('day')}`;
}

export function residenceDayDaysAgo(at: Date, days: number): string {
  return residenceDay(new Date(at.getTime() - days * DAY_MS));
}

export function ensureZoneChangeAllowed(chosenAt: Date | null, now: Date): void {
  if (!chosenAt) return;
  const availableAt = new Date(chosenAt.getTime() + 30 * DAY_MS);
  if (now < availableAt) {
    throw new BusinessRuleViolation(
      'cambio_de_zona_muy_pronto',
      'Todavía no puedes volver a cambiar de zona.',
      'conflict',
      { disponibleDesde: availableAt.toISOString() },
    );
  }
}

export function ensurePresenceDateAllowed(day: string, chosenAt: Date | null, now: Date): void {
  if (
    day > residenceDay(now) ||
    day < residenceDayDaysAgo(now, PRESENCE_WINDOW_DAYS - 1) ||
    (chosenAt && day < residenceDay(chosenAt))
  ) {
    throw new BusinessRuleViolation(
      'fecha_de_presencia_invalida',
      'La fecha debe corresponder a los últimos 14 días en tu zona actual.',
    );
  }
}
