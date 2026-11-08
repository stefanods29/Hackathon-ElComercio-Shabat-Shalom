import { Body, Controller, Delete, HttpCode, Param, Post, Res } from '@nestjs/common';
import type { Response } from 'express';
import { V1 } from '../../../shared/api/routes.js';
import type { Actor } from '../../../shared/auth/actor.js';
import { CurrentActor, RequireTrustLevel } from '../../../shared/auth/decorators.js';
import { Idempotent } from '../../../shared/idempotency/idempotent.decorator.js';
import { Endorsements } from '../application/endorsements.js';
import { WriteReview } from '../application/write-review.js';
import {
  newReviewSchema,
  reputationIdSchema,
  toEndorsementDto,
  toReviewDto,
  type NewReviewDto,
} from './schemas.js';

@Controller(V1)
export class ReputationController {
  constructor(
    private readonly writeReview: WriteReview,
    private readonly endorsements: Endorsements,
  ) {}

  @Post('resenas')
  @RequireTrustLevel(1)
  @Idempotent()
  @HttpCode(201)
  async write(
    @Body({ schema: newReviewSchema }) body: NewReviewDto,
    @CurrentActor() actor: Actor,
    @Res({ passthrough: true }) response: Response,
  ) {
    const result = await this.writeReview.execute(
      {
        id: body.id,
        serviceId: body.servicioId,
        rating: body.calificacion,
        comment: body.comentario ?? null,
        fileIds: body.fotos,
      },
      actor,
    );
    if (!result.created) response.status(200);
    return toReviewDto(result.review);
  }

  @Post('servicios/:id/visto-bueno')
  @RequireTrustLevel(1)
  @Idempotent()
  @HttpCode(200)
  async give(
    @Param('id', { schema: reputationIdSchema }) serviceId: string,
    @CurrentActor() actor: Actor,
  ) {
    return toEndorsementDto(await this.endorsements.give(serviceId, actor));
  }

  @Delete('servicios/:id/visto-bueno')
  @RequireTrustLevel(1)
  @Idempotent()
  @HttpCode(204)
  async withdraw(
    @Param('id', { schema: reputationIdSchema }) serviceId: string,
    @CurrentActor() actor: Actor,
  ): Promise<void> {
    await this.endorsements.withdraw(serviceId, actor);
  }
}
