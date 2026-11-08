import { SetMetadata } from '@nestjs/common';

export const IDEMPOTENT_METADATA = 'vecinal:idempotent';

export type IdempotencyPolicy = true | 'session-bound';

/**
 * Marks a write route: it requires `Idempotency-Key` and replays the stored response on retries.
 * Every write the phone can send from its offline queue must carry it.
 * Bind the fingerprint to the session when the response grants access only to that session.
 */
export const Idempotent = (policy: IdempotencyPolicy = true): MethodDecorator & ClassDecorator =>
  SetMetadata(IDEMPOTENT_METADATA, policy);
