import sharp from 'sharp';
import { encode } from 'blurhash';
import type { PhotoProcessor, ProcessedPhoto } from '../application/ports.js';
import { InvalidPhoto, MAX_PHOTO_PIXELS } from '../domain/photo.js';

/** libvips processes pixels off the JS thread. Metadata is stripped by default; never call keepMetadata. */
export class SharpPhotoProcessor implements PhotoProcessor {
  async process(bytes: Uint8Array): Promise<ProcessedPhoto> {
    try {
      const options = {
        limitInputPixels: MAX_PHOTO_PIXELS,
        animated: false,
        failOn: 'warning' as const,
      };
      const metadata = await sharp(bytes, options).metadata();
      if (!['jpeg', 'png', 'webp'].includes(metadata.format ?? '') || (metadata.pages ?? 1) !== 1)
        throw new InvalidPhoto('imagen_invalida');
      const { data: image, info } = await sharp(bytes, options)
        .autoOrient()
        .resize({ width: 1280, height: 1280, fit: 'inside', withoutEnlargement: true })
        .webp({ quality: 75 })
        .toBuffer({ resolveWithObject: true });
      const thumbnail = await sharp(image)
        .resize({ width: 320, height: 320, fit: 'inside', withoutEnlargement: true })
        .webp({ quality: 70 })
        .toBuffer();
      const preview = await sharp(image)
        .resize(32, 32, { fit: 'inside' })
        .ensureAlpha()
        .raw()
        .toBuffer({ resolveWithObject: true });
      return {
        image,
        thumbnail,
        width: info.width,
        height: info.height,
        blurhash: encode(
          new Uint8ClampedArray(preview.data),
          preview.info.width,
          preview.info.height,
          4,
          3,
        ),
      };
    } catch (error: unknown) {
      if (error instanceof InvalidPhoto) throw error;
      throw new InvalidPhoto('imagen_invalida');
    }
  }
}
