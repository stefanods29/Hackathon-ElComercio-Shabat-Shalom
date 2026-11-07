/** Source of the current time. Injecting it makes expiry and token tests deterministic. */
export interface Clock {
  now(): Date;
}

export const CLOCK = Symbol('CLOCK');

export const systemClock: Clock = { now: () => new Date() };
