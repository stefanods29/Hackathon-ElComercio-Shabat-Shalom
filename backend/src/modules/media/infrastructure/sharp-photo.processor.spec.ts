import sharp from 'sharp';
import { SharpPhotoProcessor } from './sharp-photo.processor.js';
import { InvalidPhoto } from '../domain/photo.js';

describe('saneamiento real de fotos', () => {
  const processor = new SharpPhotoProcessor();
  it('limita dimensiones, orienta y elimina EXIF/XMP/ICC de ambas salidas', async () => {
    const source = await sharp({
      create: { width: 1800, height: 900, channels: 3, background: '#397a67' },
    })
      .withExif({ IFD0: { Artist: 'Dato privado', ImageDescription: 'GPS privado de prueba' } })
      .jpeg()
      .toBuffer();
    expect((await sharp(source).metadata()).exif).toBeDefined();
    const result = await processor.process(source);
    for (const [bytes, max] of [
      [result.image, 1280],
      [result.thumbnail, 320],
    ] as const) {
      const metadata = await sharp(bytes).metadata();
      expect(Math.max(metadata.width!, metadata.height!)).toBeLessThanOrEqual(max);
      expect(metadata.format).toBe('webp');
      expect(metadata.exif).toBeUndefined();
      expect(metadata.xmp).toBeUndefined();
      expect(metadata.icc).toBeUndefined();
    }
    expect(result.width).toBe(1280);
    expect(result.height).toBe(640);
    expect(result.blurhash.length).toBeGreaterThan(10);
  });
  it('no amplía una imagen pequeña y rechaza SVG/texto/bytes corruptos', async () => {
    const input = await sharp({ create: { width: 24, height: 12, channels: 4, background: 'red' } })
      .png()
      .toBuffer();
    expect((await processor.process(input)).width).toBe(24);
    for (const bad of [
      Buffer.from('no es una foto'),
      Buffer.from('<svg width="2" height="2"></svg>'),
    ]) {
      await expect(processor.process(bad)).rejects.toBeInstanceOf(InvalidPhoto);
    }
  });
});
