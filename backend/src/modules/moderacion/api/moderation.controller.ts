import { Body, Controller, Get, HttpCode, Param, Post, Query, Res } from '@nestjs/common';
import type { Response } from 'express';
import { V1 } from '../../../shared/api/routes.js';
import type { Actor } from '../../../shared/auth/actor.js';
import { CurrentActor, RequireRole } from '../../../shared/auth/decorators.js';
import { Idempotent } from '../../../shared/idempotency/idempotent.decorator.js';
import { DecideCase } from '../application/decide-case.js';
import { ReadModeration } from '../application/read-moderation.js';
import { ReportContent } from '../application/report-content.js';
import {
  caseIdSchema,
  decisionSchema,
  type DecisionDto,
  metricsSchema,
  type MetricsDto,
  queueSchema,
  type QueueDto,
  reportSchema,
  type ReportDto,
  toCase,
  toReport,
} from './schemas.js';

@Controller(V1)
export class ModerationController {
  constructor(
    private readonly reports: ReportContent,
    private readonly reads: ReadModeration,
    private readonly decisions: DecideCase,
  ) {}

  @Post('denuncias')
  @HttpCode(201)
  @Idempotent()
  async report(
    @Body({ schema: reportSchema }) body: ReportDto,
    @CurrentActor() actor: Actor,
    @Res({ passthrough: true }) response: Response,
  ) {
    const result = await this.reports.execute(actor.id, {
      id: body.id.toLowerCase(),
      content: { type: body.tipoContenido, id: body.contenidoId.toLowerCase() },
      reason: body.motivo,
      details: body.detalle || null,
    });
    if (!result.created) response.status(200);
    return toReport(result.report);
  }

  @Get('moderacion/casos')
  @RequireRole('moderador')
  async cases(@Query({ schema: queueSchema }) query: QueueDto) {
    const page = await this.reads.queue(query.estado, query.limite, query.cursor);
    return { datos: page.cases.map(toCase), siguienteCursor: page.next };
  }

  @Post('moderacion/casos/:id/decision')
  @RequireRole('moderador')
  @HttpCode(200)
  @Idempotent()
  async decide(
    @Param('id', { schema: caseIdSchema }) id: string,
    @Body({ schema: decisionSchema }) body: DecisionDto,
    @CurrentActor() actor: Actor,
  ) {
    return toCase(await this.decisions.execute(id, actor.id, body.accion, body.motivo));
  }

  @Get('moderacion/metricas')
  @RequireRole('administrador')
  metrics(@Query({ schema: metricsSchema }) query: MetricsDto) {
    return this.reads.metrics(query.desde, query.hasta);
  }
}
