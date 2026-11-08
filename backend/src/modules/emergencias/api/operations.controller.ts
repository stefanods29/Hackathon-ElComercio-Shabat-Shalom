import { Body, Controller, Get, Header, HttpCode, Param, Post, Put, Query } from '@nestjs/common';
import { V1 } from '../../../shared/api/routes.js';
import type { Actor } from '../../../shared/auth/actor.js';
import { CurrentActor, RequireRole, RequireTrustLevel } from '../../../shared/auth/decorators.js';
import { Idempotent } from '../../../shared/idempotency/idempotent.decorator.js';
import { ManageOperations } from '../application/manage-operations.js';
import {
  auditQuery,
  grantOperator,
  groupMembers,
  idParams,
  newGroup,
  newShift,
  page,
  revokeOperator,
  seenVersion,
  supportZones,
  toGrantDto,
  toGroupDto,
  toShiftDto,
  zoneParams,
  type AuditQuery,
  type GrantOperatorDto,
  type GroupMembersDto,
  type IdParams,
  type NewGroupDto,
  type NewShiftDto,
  type RevokeOperatorDto,
  type SupportZonesDto,
  type VersionDto,
  type ZoneParams,
} from './schemas.js';

@Controller(`${V1}/operacion`)
@RequireTrustLevel(3)
export class EmergencyOperationsController {
  constructor(private readonly operations: ManageOperations) {}
  @Post('habilitaciones')
  @Idempotent()
  @HttpCode(200)
  @RequireRole('administrador')
  async grant(
    @Body({ schema: grantOperator }) body: GrantOperatorDto,
    @CurrentActor() actor: Actor,
  ) {
    return toGrantDto(
      await this.operations.grant(
        {
          id: body.id,
          userId: body.usuarioId,
          zoneId: body.zonaId,
          role: body.rol,
          dniReviewedAt: body.dniRevisadoEn,
          trainedAt: body.capacitacionEn,
          confidentialityAt: body.confidencialidadEn,
          reviewReference: body.referenciaRevision,
          expiresAt: body.venceEn,
          expected: body.versionVista,
        },
        actor,
      ),
    );
  }
  @Post('habilitaciones/:id/revocar')
  @Idempotent()
  @HttpCode(200)
  @RequireRole('administrador')
  async revoke(
    @Param({ schema: idParams }) params: IdParams,
    @Body({ schema: revokeOperator }) body: RevokeOperatorDto,
    @CurrentActor() actor: Actor,
  ) {
    return toGrantDto(await this.operations.revoke(params.id, body.versionVista, actor));
  }
  @Get('zonas/:zonaId/turnos')
  @Header('Cache-Control', 'no-store')
  @RequireRole('coordinador')
  async board(@Param({ schema: zoneParams }) params: ZoneParams, @CurrentActor() actor: Actor) {
    const board = await this.operations.board(params.zonaId, actor);
    return {
      operadores: board.people.map((person) => ({
        id: person.id,
        nombre: person.name,
        rol: person.role,
        activo: true,
      })),
      turnos: board.shifts.map(toShiftDto),
      actualizadoEn: board.updatedAt.toISOString(),
    };
  }
  @Get('zonas/:zonaId/personas')
  @Header('Cache-Control', 'no-store')
  @RequireRole('coordinador')
  async people(@Param({ schema: zoneParams }) params: ZoneParams, @CurrentActor() actor: Actor) {
    const board = await this.operations.board(params.zonaId, actor);
    return {
      elementos: board.people
        .filter((person) => person.shift !== null)
        .map((person) => ({ id: person.id, nombre: person.name, rol: person.role, activo: true })),
    };
  }
  @Post('zonas/:zonaId/turnos')
  @Idempotent()
  @HttpCode(200)
  @RequireRole('coordinador')
  async shift(
    @Param({ schema: zoneParams }) params: ZoneParams,
    @Body({ schema: newShift }) body: NewShiftDto,
    @CurrentActor() actor: Actor,
  ) {
    return toShiftDto(
      await this.operations.createShift(
        {
          id: body.id,
          userId: body.usuarioId,
          zoneId: params.zonaId,
          role: body.rol,
          startsAt: body.inicio,
          endsAt: body.fin,
        },
        actor,
      ),
    );
  }
  @Post('turnos/:id/finalizar')
  @Idempotent()
  @HttpCode(200)
  @RequireRole('coordinador')
  async endShift(
    @Param({ schema: idParams }) params: IdParams,
    @Body({ schema: seenVersion }) body: VersionDto,
    @CurrentActor() actor: Actor,
  ) {
    return toShiftDto(await this.operations.endShift(params.id, body.versionVista, actor));
  }
  @Get('zonas/:zonaId/grupos')
  @Header('Cache-Control', 'no-store')
  @RequireRole('coordinador')
  async groups(@Param({ schema: zoneParams }) params: ZoneParams, @CurrentActor() actor: Actor) {
    return { elementos: (await this.operations.groups(params.zonaId, actor)).map(toGroupDto) };
  }
  @Post('zonas/:zonaId/grupos')
  @Idempotent()
  @HttpCode(200)
  @RequireRole('administrador')
  async group(
    @Param({ schema: zoneParams }) params: ZoneParams,
    @Body({ schema: newGroup }) body: NewGroupDto,
    @CurrentActor() actor: Actor,
  ) {
    return toGroupDto(
      await this.operations.saveGroup(
        { id: body.id, zoneId: params.zonaId, name: body.nombre, members: body.miembros },
        actor,
      ),
    );
  }
  @Put('grupos/:id/miembros')
  @Idempotent()
  @HttpCode(200)
  @RequireRole('administrador')
  async members(
    @Param({ schema: idParams }) params: IdParams,
    @Body({ schema: groupMembers }) body: GroupMembersDto,
    @CurrentActor() actor: Actor,
  ) {
    return toGroupDto(
      await this.operations.saveGroup(
        { id: params.id, members: body.miembros, expected: body.versionVista },
        actor,
      ),
    );
  }
  @Put('zonas/:zonaId/apoyos')
  @Idempotent()
  @HttpCode(200)
  @RequireRole('administrador')
  support(
    @Param({ schema: zoneParams }) params: ZoneParams,
    @Body({ schema: supportZones }) body: SupportZonesDto,
    @CurrentActor() actor: Actor,
  ) {
    return this.operations.support(params.zonaId, body.zonas, actor);
  }
  @Get('auditoria')
  @Header('Cache-Control', 'no-store')
  @RequireRole('administrador')
  async audit(@Query({ schema: auditQuery }) query: AuditQuery, @CurrentActor() actor: Actor) {
    const entries = await this.operations.auditLog(actor, query.cursor, query.limite + 1);
    return page(
      entries.map((item) => ({
        id: item.id,
        usuarioId: item.userId,
        pedidoId: item.requestId,
        rol: item.role,
        accion: item.action,
        ocurridoEn: item.occurredAt.toISOString(),
      })),
      query.limite,
    );
  }
}
