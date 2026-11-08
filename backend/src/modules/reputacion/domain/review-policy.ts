import { BusinessRuleViolation, RateLimitExceeded } from '../../../shared/domain/errors.js';

export const REVIEW_WINDOW_MS = 24 * 60 * 60 * 1000;
const HOUR_MS = 60 * 60 * 1000;

export function assertAccountAge(createdAt: Date, now: Date, minimumHours: number): void {
  if (now.getTime() - createdAt.getTime() < minimumHours * HOUR_MS) {
    throw new BusinessRuleViolation(
      'cuenta_muy_nueva',
      'Tu cuenta aún no tiene la antigüedad para reseñar.',
      'forbidden',
    );
  }
}

export function assertReviewQuota(
  usage: { readonly count: number; readonly oldest: Date | null },
  now: Date,
  maxReviews: number,
): void {
  if (usage.count < maxReviews) return;
  const expires = (usage.oldest?.getTime() ?? now.getTime()) + REVIEW_WINDOW_MS;
  throw new RateLimitExceeded(
    'limite_diario_alcanzado',
    'Llegaste al límite diario de reseñas. Intenta de nuevo más tarde.',
    Math.max(1, Math.ceil((expires - now.getTime()) / 1000)),
  );
}
