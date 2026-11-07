import type { OtpFailureState } from './ports.js';

export function failureRetryAfter(states: readonly (OtpFailureState | null)[], now: Date): number {
  const until = Math.max(
    now.getTime(),
    ...states.map((state) => state?.blockedUntil?.getTime() ?? 0),
  );
  return Math.ceil((until - now.getTime()) / 1000);
}

/** The failure window and the subsequent block each last lockMinutes. */
export function nextFailureState(
  state: OtpFailureState | null,
  now: Date,
  maximum: number,
  lockMinutes: number,
): OtpFailureState {
  const duration = lockMinutes * 60_000;
  const expired =
    !state ||
    now.getTime() >= state.windowStartedAt.getTime() + duration ||
    (state.blockedUntil !== null && now.getTime() >= state.blockedUntil.getTime());
  const attempts = expired ? 1 : state.attempts + 1;
  return {
    attempts,
    windowStartedAt: expired ? now : state.windowStartedAt,
    blockedUntil: attempts >= maximum ? new Date(now.getTime() + duration) : null,
  };
}
