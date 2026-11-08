import { Controller, Get, HttpCode, Param, Post, Query } from '@nestjs/common';
import { z } from 'zod';
import { V1 } from '../../../shared/api/routes.js';
import type { Actor } from '../../../shared/auth/actor.js';
import { CurrentActor, RequireRole } from '../../../shared/auth/decorators.js';
import { Idempotent } from '../../../shared/idempotency/idempotent.decorator.js';
import { UrgentNotices } from '../application/urgent-notices.js';

const noticeIdSchema = z.uuid();
const summaryQuerySchema = z.strictObject({ desde: z.iso.datetime({ offset: true }).optional() });
type SummaryQuery = z.infer<typeof summaryQuerySchema>;

/**
 * Urgent notices to coordinators and brigade members (Phase 2, Lot C). The recipient lists and
 * acknowledges their own notices; administrators and coordinators see delivery and SMS cost.
 */
@Controller(V1)
export class UrgentNoticesController {
  constructor(private readonly notices: UrgentNotices) {}

  @Get('avisos-urgentes')
  pending(@CurrentActor() actor: Actor) {
    return this.notices.pendingFor(actor);
  }

  @Post('avisos-urgentes/:id/confirmar')
  @Idempotent()
  @HttpCode(200)
  confirm(@Param('id', { schema: noticeIdSchema }) id: string, @CurrentActor() actor: Actor) {
    return this.notices.confirm(actor, id);
  }

  @Get('operacion/avisos-urgentes/resumen')
  @RequireRole('administrador', 'coordinador')
  summary(@Query({ schema: summaryQuerySchema }) query: SummaryQuery) {
    return this.notices.summary(query.desde ? new Date(query.desde) : undefined);
  }
}
