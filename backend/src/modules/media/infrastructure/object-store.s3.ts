import {
  S3Client,
  PutObjectCommand,
  HeadObjectCommand,
  GetObjectCommand,
  DeleteObjectCommand,
  ListObjectsV2Command,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import type { ObjectStore, UploadPermission } from '../application/ports.js';
import { InvalidPhoto, photoKeys, type Photo } from '../domain/photo.js';

/** Credentials remain on the server. Every object is private, including processed derivatives. */
export class S3ObjectStore implements ObjectStore {
  constructor(
    private readonly client: S3Client,
    private readonly bucket: string,
  ) {}

  async signUpload(photo: Photo, expiresAt: Date): Promise<UploadPermission> {
    const headers = {
      'Content-Type': photo.contentType,
      'If-None-Match': '*',
      'Content-Length': String(photo.bytes),
    };
    const url = await getSignedUrl(
      this.client,
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: photoKeys(photo.id).original,
        ContentType: photo.contentType,
        ContentLength: photo.bytes,
        IfNoneMatch: '*',
      }),
      {
        expiresIn: Math.max(
          1,
          Math.min(300, Math.floor((expiresAt.getTime() - Date.now()) / 1000)),
        ),
        signableHeaders: new Set(['content-type', 'content-length', 'if-none-match']),
      },
    );
    return { url, headers, expiresAt };
  }
  async signRead(key: string, expiresAt: Date): Promise<string> {
    return getSignedUrl(this.client, new GetObjectCommand({ Bucket: this.bucket, Key: key }), {
      expiresIn: Math.max(1, Math.min(300, Math.floor((expiresAt.getTime() - Date.now()) / 1000))),
    });
  }
  async head(key: string) {
    try {
      const result = await this.client.send(
        new HeadObjectCommand({ Bucket: this.bucket, Key: key }),
      );
      return { bytes: result.ContentLength ?? 0, contentType: result.ContentType ?? '' };
    } catch (error: unknown) {
      if (
        typeof error === 'object' &&
        error !== null &&
        '$metadata' in error &&
        (error.$metadata as { httpStatusCode?: number }).httpStatusCode === 404
      )
        return null;
      throw new Error('No se pudo consultar el almacenamiento de fotos');
    }
  }
  async read(key: string, maxBytes: number): Promise<Uint8Array> {
    const response = await this.client.send(
      new GetObjectCommand({ Bucket: this.bucket, Key: key }),
      { abortSignal: AbortSignal.timeout(30_000) },
    );
    if (!response.Body) throw new Error('Foto no disponible');
    const parts: Uint8Array[] = [];
    let length = 0;
    for await (const chunk of response.Body as AsyncIterable<Uint8Array>) {
      length += chunk.byteLength;
      if (length > maxBytes) {
        if ('destroy' in response.Body && typeof response.Body.destroy === 'function')
          response.Body.destroy();
        throw new InvalidPhoto('imagen_invalida');
      }
      parts.push(chunk);
    }
    return Buffer.concat(parts);
  }
  async write(key: string, bytes: Uint8Array): Promise<void> {
    await this.client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: bytes,
        ContentType: 'image/webp',
        CacheControl: 'private, max-age=300',
      }),
      { abortSignal: AbortSignal.timeout(30_000) },
    );
  }
  async delete(key: string): Promise<void> {
    await this.client.send(new DeleteObjectCommand({ Bucket: this.bucket, Key: key }), {
      abortSignal: AbortSignal.timeout(30_000),
    });
  }
  async cleanup(id: string, keepVersion: string | null): Promise<void> {
    await this.delete(photoKeys(id).original);
    let cursor: string | undefined;
    do {
      const page = await this.client.send(
        new ListObjectsV2Command({
          Bucket: this.bucket,
          Prefix: `procesadas/${id}/`,
          ContinuationToken: cursor,
        }),
        { abortSignal: AbortSignal.timeout(30_000) },
      );
      for (const object of page.Contents ?? []) {
        if (
          object.Key &&
          (!keepVersion || !object.Key.startsWith(`procesadas/${id}/${keepVersion}/`))
        )
          await this.delete(object.Key);
      }
      cursor = page.IsTruncated ? page.NextContinuationToken : undefined;
    } while (cursor);
  }
  onModuleDestroy(): void {
    this.client.destroy();
  }
}
