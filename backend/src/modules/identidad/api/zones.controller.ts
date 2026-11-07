import { Body, Controller, Get, HttpCode, Put } from '@nestjs/common';
import { V1 } from '../../../shared/api/routes.js';
import type { Actor } from '../../../shared/auth/actor.js';
import { CurrentActor, Public } from '../../../shared/auth/decorators.js';
import { Idempotent } from '../../../shared/idempotency/idempotent.decorator.js';
import { ChooseZone } from '../application/choose-zone.js';
import { ListZones } from '../application/list-zones.js';
import {
  type ChooseZoneDto,
  type SessionResponse,
  chooseZoneSchema,
  toSessionResponse,
} from './schemas.js';

@Controller(V1)
export class ZonesController {
  constructor(
    private readonly listZones: ListZones,
    private readonly chooseZone: ChooseZone,
  ) {}

  @Get('zonas')
  @Public()
  async list(): Promise<{ id: string; nombre: string; distrito: string }[]> {
    const zones = await this.listZones.execute();
    return zones.map((zone) => ({ id: zone.id, nombre: zone.name, distrito: zone.district }));
  }

  @Put('yo/zona')
  @Idempotent()
  @HttpCode(200)
  async choose(
    @Body({ schema: chooseZoneSchema }) body: ChooseZoneDto,
    @CurrentActor() actor: Actor,
  ): Promise<SessionResponse> {
    const session = await this.chooseZone.execute(actor, body.zonaId);
    return toSessionResponse(session);
  }
}
