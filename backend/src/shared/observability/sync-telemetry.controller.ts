import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { V1 } from '../api/routes.js';
import { Idempotent } from '../idempotency/idempotent.decorator.js';
import { SyncTelemetry, syncTelemetrySchema, type SyncTelemetryReport } from './sync-telemetry.js';

/**
 * Daily counters of each phone (Lot A, part 3). It needs a session to limit abuse, but the handler
 * never reads the actor: the stored row has no identity. The idempotency record keeps the
 * neighbor's scope only for its normal retention.
 */
@Controller(`${V1}/telemetria`)
export class SyncTelemetryController {
  constructor(private readonly telemetry: SyncTelemetry) {}

  @Post('sincronizacion')
  @Idempotent()
  @HttpCode(202)
  record(@Body({ schema: syncTelemetrySchema }) body: SyncTelemetryReport) {
    return this.telemetry.record(body);
  }
}
