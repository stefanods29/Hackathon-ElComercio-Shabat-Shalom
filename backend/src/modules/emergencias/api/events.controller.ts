import { Body, Controller, Get, Header, HttpCode, Param, Post } from '@nestjs/common';
import { V1 } from '../../../shared/api/routes.js';
import type { Actor } from '../../../shared/auth/actor.js';
import { CurrentActor, RequireRole, RequireTrustLevel } from '../../../shared/auth/decorators.js';
import { Idempotent } from '../../../shared/idempotency/idempotent.decorator.js';
import { ManageEvents } from '../application/manage-events.js';
import {
  closeEvent,
  idParams,
  newEvent,
  toEventDto,
  zoneParams,
  type CloseEventDto,
  type IdParams,
  type NewEventDto,
  type ZoneParams,
} from './schemas.js';

@Controller(V1)
export class EmergencyEventsController {
  constructor(private readonly events: ManageEvents) {}
  @Get('zonas/:zonaId/eventos')
  @Header('Cache-Control', 'no-store')
  async list(@Param({ schema: zoneParams }) params: ZoneParams, @CurrentActor() actor: Actor) {
    return { elementos: (await this.events.list(params.zonaId, actor)).map(toEventDto) };
  }
  @Get('zonas/:zonaId/cobertura')
  @Header('Cache-Control', 'no-store')
  coverage(@Param({ schema: zoneParams }) params: ZoneParams, @CurrentActor() actor: Actor) {
    return this.events.coverage(params.zonaId, actor);
  }
  @Post('zonas/:zonaId/eventos')
  @Idempotent()
  @HttpCode(200)
  @RequireTrustLevel(3)
  @RequireRole('coordinador')
  async activate(
    @Param({ schema: zoneParams }) params: ZoneParams,
    @Body({ schema: newEvent }) body: NewEventDto,
    @CurrentActor() actor: Actor,
  ) {
    return toEventDto(
      await this.events.activate({ id: body.id, zoneId: params.zonaId, level: body.nivel }, actor),
    );
  }
  @Post('eventos/:id/cerrar')
  @Idempotent()
  @HttpCode(200)
  @RequireTrustLevel(3)
  @RequireRole('coordinador')
  async close(
    @Param({ schema: idParams }) params: IdParams,
    @Body({ schema: closeEvent }) body: CloseEventDto,
    @CurrentActor() actor: Actor,
  ) {
    return toEventDto(await this.events.close(params.id, body.versionVista, body.motivo, actor));
  }
  @Get('eventos/:id/resumen')
  @Header('Cache-Control', 'no-store')
  @RequireTrustLevel(3)
  @RequireRole('coordinador', 'administrador')
  summary(@Param({ schema: idParams }) params: IdParams, @CurrentActor() actor: Actor) {
    return this.events.summary(params.id, actor);
  }
}
