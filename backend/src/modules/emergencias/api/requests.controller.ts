import { Body, Controller, Get, Header, HttpCode, Param, Post, Query } from '@nestjs/common';
import { V1 } from '../../../shared/api/routes.js';
import type { Actor } from '../../../shared/auth/actor.js';
import { CurrentActor, RequireRole, RequireTrustLevel } from '../../../shared/auth/decorators.js';
import { Idempotent } from '../../../shared/idempotency/idempotent.decorator.js';
import { ManageHelpRequests } from '../application/manage-help-requests.js';
import {
  assignRequest,
  changeState,
  idParams,
  newRequest,
  page,
  pageQuery,
  prioritizeRequest,
  toRequestDto,
  zoneParams,
  type AssignRequestDto,
  type ChangeStateDto,
  type IdParams,
  type NewRequestDto,
  type PageQuery,
  type PrioritizeRequestDto,
  type ZoneParams,
} from './schemas.js';

@Controller(V1)
export class HelpRequestsController {
  constructor(private readonly requests: ManageHelpRequests) {}
  @Post('pedidos-ayuda/:id/prioridad')
  @Idempotent()
  @HttpCode(200)
  @RequireTrustLevel(3)
  @RequireRole('coordinador')
  async prioritize(
    @Param({ schema: idParams }) params: IdParams,
    @Body({ schema: prioritizeRequest }) body: PrioritizeRequestDto,
    @CurrentActor() actor: Actor,
  ) {
    return toRequestDto(
      await this.requests.prioritize(
        params.id,
        body.versionVista,
        body.prioridad,
        body.motivo,
        actor,
      ),
    );
  }
  @Post('pedidos-ayuda')
  @Idempotent()
  @HttpCode(200)
  @RequireTrustLevel(0)
  async create(@Body({ schema: newRequest }) body: NewRequestDto, @CurrentActor() actor: Actor) {
    return toRequestDto(
      await this.requests.create(
        {
          id: body.id,
          eventId: body.eventoId,
          need: body.necesidad,
          priority: body.prioridad,
          description: body.descripcion,
          location: body.ubicacion,
          lifeThreatening: body.riesgoVital,
        },
        actor,
      ),
    );
  }
  @Get('pedidos-ayuda')
  @Header('Cache-Control', 'no-store')
  async own(@Query({ schema: pageQuery }) query: PageQuery, @CurrentActor() actor: Actor) {
    const result = await this.requests.list(actor, {
      cursor: query.cursor,
      limit: query.limite + 1,
    });
    return page(
      result.map((request) => toRequestDto(request)),
      query.limite,
    );
  }
  @Get('operacion/zonas/:zonaId/casos')
  @Header('Cache-Control', 'no-store')
  @RequireTrustLevel(3)
  @RequireRole('coordinador')
  async queue(
    @Param({ schema: zoneParams }) params: ZoneParams,
    @Query({ schema: pageQuery }) query: PageQuery,
    @CurrentActor() actor: Actor,
  ) {
    const result = await this.requests.list(
      actor,
      { cursor: query.cursor, limit: query.limite + 1 },
      params.zonaId,
    );
    return page(
      result.map((request) => toRequestDto(request, request.assignments)),
      query.limite,
    );
  }
  @Get('pedidos-ayuda/:id')
  @Header('Cache-Control', 'no-store')
  async detail(@Param({ schema: idParams }) params: IdParams, @CurrentActor() actor: Actor) {
    const detail = await this.requests.detail(params.id, actor);
    return {
      ...toRequestDto(detail.request, detail.assignments),
      descripcion: detail.description,
      ubicacionExacta: detail.exactLocation,
      historial: detail.history.map((item) => ({
        desde: item.from,
        hasta: item.to,
        rol: item.role,
        ocurridoEn: item.at.toISOString(),
        motivo: item.reason,
      })),
    };
  }
  @Post('pedidos-ayuda/:id/estado')
  @Idempotent()
  @HttpCode(200)
  async change(
    @Param({ schema: idParams }) params: IdParams,
    @Body({ schema: changeState }) body: ChangeStateDto,
    @CurrentActor() actor: Actor,
  ) {
    return toRequestDto(
      await this.requests.change(params.id, body.versionVista, body.estado, body.motivo, actor),
    );
  }
  @Post('pedidos-ayuda/:id/asignaciones')
  @Idempotent()
  @HttpCode(200)
  @RequireTrustLevel(3)
  @RequireRole('coordinador')
  async assign(
    @Param({ schema: idParams }) params: IdParams,
    @Body({ schema: assignRequest }) body: AssignRequestDto,
    @CurrentActor() actor: Actor,
  ) {
    return toRequestDto(
      await this.requests.assign(params.id, body.versionVista, body.usuarioId, actor, body.rol),
    );
  }
}
