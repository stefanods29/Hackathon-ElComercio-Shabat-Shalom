import { GetObjectCommand, NoSuchKey, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import type { PublicContentPublisher } from '../application/ports.js';

export class S3Publisher implements PublicContentPublisher {
  readonly enabled = true;

  constructor(
    private readonly client: S3Client,
    private readonly bucket: string,
  ) {}

  async read(relativePath: string): Promise<Buffer | null> {
    const key = this.key(relativePath);
    try {
      const response = await this.client.send(
        new GetObjectCommand({ Bucket: this.bucket, Key: key }),
        {
          abortSignal: AbortSignal.timeout(10_000),
        },
      );
      if (!response.Body) throw new Error('El objeto del directorio no tiene contenido');
      return Buffer.from(await response.Body.transformToByteArray());
    } catch (error) {
      if (error instanceof NoSuchKey) return null;
      throw new Error('No se pudo leer el directorio de emergencia del almacenamiento');
    }
  }

  async write(relativePath: string, body: Buffer, contentType: string): Promise<void> {
    const key = this.key(relativePath);
    try {
      await this.client.send(
        new PutObjectCommand({
          Bucket: this.bucket,
          Key: key,
          Body: body,
          ContentType: contentType,
          CacheControl: key === 'emergencia/indice.json' ? 'public, max-age=60' : 'no-cache',
        }),
        { abortSignal: AbortSignal.timeout(10_000) },
      );
    } catch {
      throw new Error('No se pudo escribir el directorio de emergencia en el almacenamiento');
    }
  }

  onModuleDestroy(): void {
    this.client.destroy();
  }

  private key(relativePath: string): string {
    if (!/^emergencia\/[a-z0-9-]+\.json$/u.test(relativePath)) {
      throw new Error('La ruta queda fuera del directorio de emergencia');
    }
    return relativePath;
  }
}
