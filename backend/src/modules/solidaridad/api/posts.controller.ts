import { Body, Controller, Get, HttpCode, Param, Post, Query, Res } from '@nestjs/common';
import type { Response } from 'express';
import { V1 } from '../../../shared/api/routes.js';
import type { Actor } from '../../../shared/auth/actor.js';
import { CurrentActor, RequireTrustLevel } from '../../../shared/auth/decorators.js';
import { Idempotent } from '../../../shared/idempotency/idempotent.decorator.js';
import { PublishPost } from '../application/publish-post.js';
import { TakeFavor } from '../application/take-favor.js';
import { CancelPost } from '../application/cancel-post.js';
import { ResolveFavor } from '../application/resolve-favor.js';
import { FindNearbyPosts } from '../application/find-nearby-posts.js';
import {
  type NewPostDto,
  type PostDto,
  type TakeFavorDto,
  newPostSchema,
  postIdSchema,
  takeFavorSchema,
  toPostDto,
  type ChangePostStatusDto,
  type NearbyPostsDto,
  type NearbyPostsResponse,
  changePostStatusSchema,
  nearbyPostsSchema,
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
    private readonly cancelPost: CancelPost,
    private readonly resolveFavor: ResolveFavor,
    private readonly findNearby: FindNearbyPosts,
  ) {}

  @Get()
  async nearby(
    @Query({ schema: nearbyPostsSchema }) query: NearbyPostsDto,
    @CurrentActor() actor: Actor,
  ): Promise<NearbyPostsResponse> {
    const page = await this.findNearby.execute(
      {
        location: { lat: query.lat, lng: query.lng },
        radius: query.radio,
        limit: query.limite,
        cursor: query.cursor,
      },
      actor,
    );
    return {
      datos: page.data.map((item) => ({
        ...toPostDto(item.post),
        distanciaMetros: item.distanceMeters,
      })),
      siguienteCursor: page.nextCursor,
    };
  }

  @Post(':id/cancelar')
  @Idempotent()
  @HttpCode(200)
  async cancel(
    @Param('id', { schema: postIdSchema }) id: string,
    @Body({ schema: changePostStatusSchema }) body: ChangePostStatusDto,
    @CurrentActor() actor: Actor,
  ): Promise<PostDto> {
    return toPostDto(
      await this.cancelPost.execute({ postId: id, seenVersion: body.versionVista }, actor),
    );
  }

  @Post(':id/resolver')
  @Idempotent()
  @HttpCode(200)
  async resolve(
    @Param('id', { schema: postIdSchema }) id: string,
    @Body({ schema: changePostStatusSchema }) body: ChangePostStatusDto,
    @CurrentActor() actor: Actor,
  ): Promise<PostDto> {
    return toPostDto(
      await this.resolveFavor.execute({ postId: id, seenVersion: body.versionVista }, actor),
    );
  }

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
