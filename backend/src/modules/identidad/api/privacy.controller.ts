import {
  Body,
  Controller,
  Delete,
  Get,
  Header,
  HttpCode,
  Param,
  Patch,
  Post,
} from '@nestjs/common';
import { V1 } from '../../../shared/api/routes.js';
import type { Actor } from '../../../shared/auth/actor.js';
import { CurrentActor, RequireRole, RequireTrustLevel } from '../../../shared/auth/decorators.js';
import { Idempotent } from '../../../shared/idempotency/idempotent.decorator.js';
import { ManageAccountPrivacy } from '../application/manage-account-privacy.js';
import { ManageConsents } from '../application/manage-consents.js';
import { RecordResidence } from '../application/record-residence.js';
import {
  confirmationSchema,
  type ConfirmationDto,
  consentSchema,
  type ConsentDto,
  presenceSchema,
  type PresenceDto,
  rectificationSchema,
  type RectificationDto,
  residenceIdSchema,
} from './privacy.schemas.js';

@Controller(V1)
export class PrivacyController {
  constructor(
    private readonly residence: RecordResidence,
    private readonly consents: ManageConsents,
    private readonly privacy: ManageAccountPrivacy,
  ) {}

  @Post('yo/residencia/presencia')
  @Idempotent()
  @HttpCode(200)
  async reportPresence(
    @Body({ schema: presenceSchema }) body: PresenceDto,
    @CurrentActor() actor: Actor,
  ) {
    return { nivel: await this.residence.reportPresence(actor, body.fecha, body.dentroDeLaZona) };
  }

  @Post('vecinos/:id/residencia')
  @RequireRole('moderador')
  @Idempotent()
  @HttpCode(200)
  async confirm(
    @Param('id', { schema: residenceIdSchema }) id: string,
    @Body({ schema: confirmationSchema }) body: ConfirmationDto,
    @CurrentActor() actor: Actor,
  ) {
    return { nivel: await this.residence.confirmManually(actor.id, id, body.motivo, body.nivel) };
  }

  @Post('vecinos/:id/aval')
  @RequireTrustLevel(2)
  @Idempotent()
  @HttpCode(200)
  async endorse(
    @Param('id', { schema: residenceIdSchema }) id: string,
    @CurrentActor() actor: Actor,
  ) {
    return { nivel: await this.residence.endorse(actor.id, id) };
  }

  @Get('yo/consentimientos')
  listConsents(@CurrentActor() actor: Actor) {
    return this.consents.list(actor.id);
  }

  @Post('yo/consentimientos')
  @Idempotent()
  @HttpCode(200)
  decideConsent(@Body({ schema: consentSchema }) body: ConsentDto, @CurrentActor() actor: Actor) {
    return this.consents.decide(actor.id, body.finalidad, body.version, body.aceptado);
  }

  @Get('yo/datos')
  @Header('Cache-Control', 'no-store')
  export(@CurrentActor() actor: Actor) {
    return this.privacy.export(actor.id);
  }

  @Patch('yo')
  @Idempotent()
  async rectify(
    @Body({ schema: rectificationSchema }) body: RectificationDto,
    @CurrentActor() actor: Actor,
  ) {
    await this.privacy.rectify(actor.id, body.nombreVisible);
    return { nombreVisible: body.nombreVisible };
  }

  @Delete('yo')
  @Idempotent()
  @HttpCode(202)
  cancel(@CurrentActor() actor: Actor): Promise<void> {
    return this.privacy.requestDeletion(actor.id);
  }
}
