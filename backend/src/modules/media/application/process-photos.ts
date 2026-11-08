import { Inject, Injectable } from '@nestjs/common';
import { createHash } from 'node:crypto';
import { MAX_PHOTO_BYTES, InvalidPhoto, photoKeys } from '../domain/photo.js';
import {
  PHOTO_REPOSITORY,
  OBJECT_STORE,
  PHOTO_PROCESSOR,
  type PhotoRepository,
  type ObjectStore,
  type PhotoProcessor,
} from './ports.js';

@Injectable()
export class ProcessPhotos {
  constructor(
    @Inject(PHOTO_REPOSITORY) private readonly photos: PhotoRepository,
    @Inject(OBJECT_STORE) private readonly objects: ObjectStore,
    @Inject(PHOTO_PROCESSOR) private readonly processor: PhotoProcessor,
  ) {}

  async next(): Promise<boolean> {
    const cleanup = await this.photos.claimCleanup();
    if (cleanup) {
      // Wait for outstanding upload URLs to expire before cleanup is eligible in the repository.
      await this.objects.cleanup(
        cleanup.photo.id,
        cleanup.photo.state === 'listo' ? cleanup.photo.processedVersion : null,
      );
      await this.photos.finishCleanup(cleanup);
      return true;
    }
    const claim = await this.photos.claim();
    if (!claim) return false;
    const keys = photoKeys(claim.photo.id, claim.leaseId);
    try {
      const bytes = await this.objects.read(keys.original, MAX_PHOTO_BYTES);
      if (
        bytes.byteLength !== claim.photo.bytes ||
        createHash('sha256').update(bytes).digest('hex') !== claim.photo.sha256
      ) {
        throw new InvalidPhoto('contenido_distinto');
      }
      const processed = await this.processor.process(bytes);
      await this.objects.write(keys.image, processed.image);
      await this.objects.write(keys.thumbnail, processed.thumbnail);
      const accepted = await this.photos.finish(claim, processed);
      if (!accepted) {
        await this.objects.delete(keys.image);
        await this.objects.delete(keys.thumbnail);
      }
    } catch (error: unknown) {
      await this.photos.fail(
        claim,
        error instanceof InvalidPhoto ? error.reason : 'error_de_procesamiento',
        error instanceof InvalidPhoto,
      );
    }
    return true;
  }
}
