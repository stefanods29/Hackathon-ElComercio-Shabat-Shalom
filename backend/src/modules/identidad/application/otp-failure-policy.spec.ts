import { failureRetryAfter, nextFailureState } from './otp-failure-policy.js';
import type { OtpFailureState } from './ports.js';

describe('Política de fallos OTP', () => {
  const now = new Date('2026-11-07T15:00:00Z');

  it('inicia el bloqueo al alcanzar el límite y no al comenzar la ventana', () => {
    const previous: OtpFailureState = {
      attempts: 4,
      windowStartedAt: new Date(now.getTime() - 4 * 60_000),
      blockedUntil: null,
    };
    const next = nextFailureState(previous, now, 5, 15);
    expect(next.attempts).toBe(5);
    expect(failureRetryAfter([next], now)).toBe(900);
  });

  it('espera hasta que hayan terminado ambos bloqueos y redondea hacia arriba', () => {
    const state = {
      attempts: 5,
      windowStartedAt: now,
      blockedUntil: new Date(now.getTime() + 1001),
    };
    expect(failureRetryAfter([null, state], now)).toBe(2);
    expect(
      failureRetryAfter([state, { ...state, blockedUntil: new Date(now.getTime() + 5000) }], now),
    ).toBe(5);
    expect(failureRetryAfter([state], new Date(now.getTime() + 1001))).toBe(0);
  });

  it('empieza una ventana nueva cuando vence el bloqueo o la ventana sin alcanzar el límite', () => {
    const previous = {
      attempts: 5,
      windowStartedAt: now,
      blockedUntil: new Date(now.getTime() + 15 * 60_000),
    };
    const later = new Date(now.getTime() + 15 * 60_000);
    expect(nextFailureState(previous, later, 5, 15)).toEqual({
      attempts: 1,
      windowStartedAt: later,
      blockedUntil: null,
    });
    expect(
      nextFailureState({ ...previous, attempts: 4, blockedUntil: null }, later, 5, 15),
    ).toEqual({ attempts: 1, windowStartedAt: later, blockedUntil: null });
  });
});
