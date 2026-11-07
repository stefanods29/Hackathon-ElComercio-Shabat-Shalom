import { SetMetadata } from '@nestjs/common';

export const IDEMPOTENT_METADATA = 'vecinal:idempotent';

/**
 * Marks a write route: it requires `Idempotency-Key` and replays the stored response on retries.
 * Every write the phone can send from its offline queue must carry it.
 */
export const Idempotent = (): MethodDecorator & ClassDecorator =>
  SetMetadata(IDEMPOTENT_METADATA, true);
