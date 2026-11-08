import { Inject, Injectable } from '@nestjs/common';
import type { Actor } from '../../../shared/auth/actor.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { BusinessRuleViolation, ResourceNotFound } from '../../../shared/domain/errors.js';
import {
  PHOTO_UPLOAD_SECONDS,
  photoKeys,
  type Photo,
  type PhotoContentType,
} from '../domain/photo.js';
import { PHOTO_REPOSITORY, OBJECT_STORE, type PhotoRepository, type ObjectStore } from './ports.js';

@Injectable()
export class ManagePhotos {
  constructor(
    @Inject(PHOTO_REPOSITORY) private readonly photos: PhotoRepository,
    @Inject(OBJECT_STORE) private readonly objects: ObjectStore,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  async reserve(
    input: { id: string; bytes: number; sha256: string; contentType: PhotoContentType },
    actor: Actor,
  ): Promise<Photo> {
    if (!actor.zoneId || actor.trustLevel < 1)
      throw new BusinessRuleViolation(
        'identidad_insuficiente',
        'Confirma tu cuenta y elige una zona antes de subir fotos.',
        'forbidden',
      );
    return this.photos.reserve({
      ...input,
      ownerId: actor.id,
      zoneId: actor.zoneId,
      state: 'pendiente_subida',
      createdAt: this.clock.now(),
      width: null,
      height: null,
      blurhash: null,
      failure: null,
      processedVersion: null,
    });
  }

  async owned(id: string, actor: Actor): Promise<Photo> {
    const photo = await this.photos.findOwned(id, actor.id);
    if (!photo || photo.state === 'eliminado') throw new ResourceNotFound('el archivo', id);
    return photo;
  }

  async signUpload(id: string, actor: Actor) {
    const photo = await this.owned(id, actor);
    if (photo.state !== 'pendiente_subida')
      throw new BusinessRuleViolation(
        'archivo_no_subible',
        'La foto ya fue confirmada. Consulta su estado.',
        'conflict',
      );
    const expires = new Date(this.clock.now().getTime() + PHOTO_UPLOAD_SECONDS * 1000);
    if (!(await this.photos.allowUploadUntil(id, actor.id, expires)))
      throw new BusinessRuleViolation(
        'archivo_no_subible',
        'La foto ya no permite nuevas subidas.',
        'conflict',
      );
    return this.objects.signUpload(photo, expires);
  }

  async confirm(id: string, actor: Actor): Promise<Photo> {
    const photo = await this.owned(id, actor);
    if (photo.state !== 'pendiente_subida') return photo;
    const head = await this.objects.head(photoKeys(id).original);
    if (!head)
      throw new BusinessRuleViolation(
        'subida_pendiente',
        'La foto todavía no llegó. Vuelve a intentarlo.',
        'conflict',
      );
    if (head.bytes !== photo.bytes || head.contentType !== photo.contentType)
      throw new BusinessRuleViolation(
        'archivo_distinto',
        'La foto subida no coincide con el archivo reservado. Selecciónala de nuevo.',
      );
    await this.photos.enqueue(id, actor.id);
    return this.owned(id, actor);
  }

  async view(id: string, actor: Actor) {
    const photo = await this.owned(id, actor);
    const result = {
      id: photo.id,
      estado: photo.state,
      bytes: photo.bytes,
      creadoEn: photo.createdAt.toISOString(),
      ancho: photo.width,
      alto: photo.height,
      blurhash: photo.blurhash,
      motivo: photo.failure,
    };
    if (photo.state !== 'listo') return result;
    const expires = new Date(this.clock.now().getTime() + PHOTO_UPLOAD_SECONDS * 1000);
    const keys = photoKeys(id, photo.processedVersion!);
    const [url, miniaturaUrl] = await Promise.all([
      this.objects.signRead(keys.image, expires),
      this.objects.signRead(keys.thumbnail, expires),
    ]);
    return { ...result, url, miniaturaUrl, urlsVencenEn: expires.toISOString() };
  }

  async remove(id: string, actor: Actor): Promise<void> {
    // Also accepts a repeated removal; the worker owns recoverable object cleanup.
    if (!(await this.photos.findOwned(id, actor.id))) throw new ResourceNotFound('el archivo', id);
    await this.photos.remove(id, actor.id);
  }
}
