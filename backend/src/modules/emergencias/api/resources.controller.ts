import {
  Body,
  Controller,
  Get,
  Header,
  HttpCode,
  Inject,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { V1 } from '../../../shared/api/routes.js';
import type { Actor } from '../../../shared/auth/actor.js';
import { CurrentActor, RequireRole, RequireTrustLevel } from '../../../shared/auth/decorators.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { Idempotent } from '../../../shared/idempotency/idempotent.decorator.js';
import { ManageResources } from '../application/manage-resources.js';
import { cellBounds } from '../domain/emergency.js';
import {
  idParams,
  newResource,
  page,
  pageQuery,
  seenVersion,
  toResourceDto,
  updateResource,
  verifyResource,
  zoneParams,
  type IdParams,
  type NewResourceDto,
  type PageQuery,
  type UpdateResourceDto,
  type VerifyResourceDto,
  type VersionDto,
  type ZoneParams,
} from './schemas.js';

@Controller(V1)
export class EmergencyResourcesController {
  constructor(
    private readonly resources: ManageResources,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}
  @Get('zonas/:zonaId/recursos')
  @Header('Cache-Control', 'no-store')
  async list(
    @Param({ schema: zoneParams }) params: ZoneParams,
    @Query({ schema: pageQuery }) query: PageQuery,
    @CurrentActor() actor: Actor,
  ) {
    const rows = await this.resources.list(params.zonaId, actor, query.cursor, query.limite + 1);
    return page(
      rows.map((row) => toResourceDto(row, this.clock.now())),
      query.limite,
    );
  }
  @Post('zonas/:zonaId/recursos')
  @Idempotent()
  @HttpCode(200)
  @RequireTrustLevel(1)
  async report(
    @Param({ schema: zoneParams }) params: ZoneParams,
    @Body({ schema: newResource }) body: NewResourceDto,
    @CurrentActor() actor: Actor,
  ) {
    return toResourceDto(
      await this.resources.report(
        {
          id: body.id,
          zoneId: params.zonaId,
          type: body.tipo,
          quantity: body.cantidad,
          location: body.ubicacion,
        },
        actor,
      ),
      this.clock.now(),
    );
  }
  @Patch('recursos-criticos/:id')
  @Idempotent()
  @HttpCode(200)
  @RequireTrustLevel(1)
  async update(
    @Param({ schema: idParams }) params: IdParams,
    @Body({ schema: updateResource }) body: UpdateResourceDto,
    @CurrentActor() actor: Actor,
  ) {
    return toResourceDto(
      await this.resources.update(params.id, body.versionVista, body.cantidad, actor),
      this.clock.now(),
    );
  }
  @Post('recursos-criticos/:id/confirmaciones')
  @Idempotent()
  @HttpCode(200)
  @RequireTrustLevel(1)
  async confirm(
    @Param({ schema: idParams }) params: IdParams,
    @Body({ schema: seenVersion }) body: VersionDto,
    @CurrentActor() actor: Actor,
  ) {
    return toResourceDto(
      await this.resources.confirm(params.id, body.versionVista, actor),
      this.clock.now(),
    );
  }
  @Post('recursos-criticos/:id/verificacion')
  @Idempotent()
  @HttpCode(200)
  @RequireTrustLevel(3)
  @RequireRole('coordinador', 'curador', 'administrador')
  async verify(
    @Param({ schema: idParams }) params: IdParams,
    @Body({ schema: verifyResource }) body: VerifyResourceDto,
    @CurrentActor() actor: Actor,
  ) {
    return toResourceDto(
      await this.resources.verify(
        params.id,
        body.versionVista,
        { label: body.etiqueta, sourceUrl: body.fuenteUrl, official: body.oficial },
        actor,
      ),
      this.clock.now(),
    );
  }
  @Get('zonas/:zonaId/celdas')
  @Header('Cache-Control', 'no-store')
  async cells(@Param({ schema: zoneParams }) params: ZoneParams, @CurrentActor() actor: Actor) {
    const cells = await this.resources.cells(params.zonaId, actor);
    return {
      elementos: cells.map((cell) => ({
        id: cell.id,
        limites: cellBounds(cell.cell),
        necesidad: cell.need,
        cantidad: cell.count,
        actualizadoEn: cell.updatedAt.toISOString(),
      })),
      actualizadoEn: cells[0]?.updatedAt.toISOString() ?? null,
    };
  }
}
