import { Injectable } from '@nestjs/common';
import type { ImageScreening } from '../domain/screening.js';
import type { ImageModeration } from './ports.js';

/** Media can register its inspector in both the HTTP and worker processes. */
@Injectable()
export class ImageModerationRegistry implements ImageModeration {
  private inspector?: ImageModeration;

  register(inspector: ImageModeration): void {
    if (this.inspector) throw new Error('Ya está registrado el filtro de imágenes.');
    this.inspector = inspector;
  }

  async inspect(fileId: string): Promise<ImageScreening> {
    return this.inspector ? this.inspector.inspect(fileId) : 'sin_verificar';
  }
}
