import { ServiceUnavailableException } from '@nestjs/common';
import type { PublicContentPublisher } from '../application/ports.js';

/**
 * `CURATION_PUBLISH_DRIVER=disabled`: the routes answer 503 instead of pretending to publish.
 * Production uses it until the cloud storage adapter of Phase 1 (Lot C) is wired here.
 */
export class DisabledPublisher implements PublicContentPublisher {
  readonly enabled = false;

  async read(): Promise<Buffer | null> {
    return null;
  }

  async write(): Promise<void> {
    throw new ServiceUnavailableException();
  }
}
