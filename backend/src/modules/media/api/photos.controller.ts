import { Body, Controller, Get, HttpCode, Param, Post, Res } from '@nestjs/common';
import type { Response } from 'express';
import { z } from 'zod';
import type { Actor } from '../../../shared/auth/actor.js';
import { CurrentActor } from '../../../shared/auth/decorators.js';
import { Idempotent } from '../../../shared/idempotency/idempotent.decorator.js';
import { ManagePhotos } from '../application/manage-photos.js';
import { MAX_PHOTO_BYTES } from '../domain/photo.js';

const idSchema = z.uuid();
const newPhotoSchema = z.strictObject({
  id: idSchema,
  tipoContenido: z.enum(['image/jpeg', 'image/png', 'image/webp']),
  bytes: z.number().int().min(1).max(MAX_PHOTO_BYTES),
  sha256: z.string().regex(/^[0-9a-f]{64}$/),
});

@Controller('v1/archivos')
export class PhotosController {
  constructor(private readonly photos: ManagePhotos) {}

  @Post()
  @Idempotent()
  @HttpCode(200)
  async reserve(
    @Body({ schema: newPhotoSchema }) body: z.infer<typeof newPhotoSchema>,
    @CurrentActor() actor: Actor,
  ) {
    await this.photos.reserve(
      { id: body.id, bytes: body.bytes, sha256: body.sha256, contentType: body.tipoContenido },
      actor,
    );
    return this.photos.view(body.id, actor);
  }
  @Get(':id')
  async view(
    @Param('id', { schema: idSchema }) id: string,
    @CurrentActor() actor: Actor,
    @Res({ passthrough: true }) response: Response,
  ) {
    response.setHeader('Cache-Control', 'no-store');
    return this.photos.view(id, actor);
  }
  @Post(':id/subida')
  @Idempotent()
  @HttpCode(200)
  async sign(
    @Param('id', { schema: idSchema }) id: string,
    @CurrentActor() actor: Actor,
    @Res({ passthrough: true }) response: Response,
  ) {
    response.setHeader('Cache-Control', 'no-store');
    const permission = await this.photos.signUpload(id, actor);
    return {
      url: permission.url,
      encabezados: permission.headers,
      venceEn: permission.expiresAt.toISOString(),
    };
  }
  @Post(':id/confirmar')
  @Idempotent()
  @HttpCode(200)
  async confirm(@Param('id', { schema: idSchema }) id: string, @CurrentActor() actor: Actor) {
    await this.photos.confirm(id, actor);
    return this.photos.view(id, actor);
  }
  @Post(':id/baja')
  @Idempotent()
  @HttpCode(200)
  async remove(@Param('id', { schema: idSchema }) id: string, @CurrentActor() actor: Actor) {
    await this.photos.remove(id, actor);
    return { id, estado: 'eliminado' };
  }
}
