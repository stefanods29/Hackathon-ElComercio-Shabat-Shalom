import { Body, Controller, HttpCode, Param, Post, Res } from '@nestjs/common';
import type { Response } from 'express';
import { V1 } from '../../../shared/api/routes.js';
import type { Actor } from '../../../shared/auth/actor.js';
import { CurrentActor, RequireTrustLevel } from '../../../shared/auth/decorators.js';
import { Idempotent } from '../../../shared/idempotency/idempotent.decorator.js';
import { PublishPost } from '../application/publish-post.js';
import { TakeFavor } from '../application/take-favor.js';
import {
  type NewPostDto,
  type PostDto,
  type TakeFavorDto,
  newPostSchema,
  postIdSchema,
  takeFavorSchema,
  toPostDto,
} from './schemas.js';

/**
 * Favor wall (Phase 0 reference implementation: copy this pattern in your modules).
 * Every write is idempotent: the phone retries from its queue without creating duplicates.
 */
@Controller(`${V1}/publicaciones`)
export class PostsController {
  constructor(
    private readonly publishPost: PublishPost,
    private readonly takeFavor: TakeFavor,
  ) {}

  /** 201 when created; 200 when the phone retried and it already existed (no duplicates). */
  @Post()
  @RequireTrustLevel(1)
  @Idempotent()
  @HttpCode(201)
  async publish(
    @Body({ schema: newPostSchema }) body: NewPostDto,
    @CurrentActor() actor: Actor,
    @Res({ passthrough: true }) response: Response,
  ): Promise<PostDto> {
    const result = await this.publishPost.execute(
      {
        id: body.id,
        type: body.tipo,
        category: body.categoria,
        title: body.titulo,
        description: body.descripcion ?? null,
        location: body.ubicacion ?? null,
        expiresAt: body.venceEn ? new Date(body.venceEn) : null,
      },
      actor,
    );
    if (!result.created) {
      response.status(200);
    }
    return toPostDto(result.post);
  }

  /** 409 `favor_no_disponible` if another neighbor took it first; 409 `conflicto_de_version` if it changed. */
  @Post(':id/tomar')
  @RequireTrustLevel(1)
  @Idempotent()
  @HttpCode(200)
  async take(
    @Param('id', { schema: postIdSchema }) id: string,
    @Body({ schema: takeFavorSchema }) body: TakeFavorDto,
    @CurrentActor() actor: Actor,
  ): Promise<PostDto> {
    const post = await this.takeFavor.execute(
      { postId: id, seenVersion: body.versionVista },
      actor,
    );
    return toPostDto(post);
  }
}
