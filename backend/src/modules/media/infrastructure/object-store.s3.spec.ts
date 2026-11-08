import { S3Client } from '@aws-sdk/client-s3';
import { S3ObjectStore } from './object-store.s3.js';
import type { Photo } from '../domain/photo.js';

describe('firma S3 sin red', () => {
  it('firma una única ruta privada, con tamaño, MIME y protección de sobrescritura', async () => {
    const client = new S3Client({
      endpoint: 'https://storage.example',
      region: 'auto',
      forcePathStyle: true,
      credentials: { accessKeyId: 'clave-de-prueba', secretAccessKey: 'secreto-de-prueba' },
      requestChecksumCalculation: 'WHEN_REQUIRED',
    });
    const storage = new S3ObjectStore(client, 'fotos-privadas');
    const photo: Photo = {
      id: '01970000-0000-7000-8000-00000000f001',
      ownerId: 'no-viaja',
      zoneId: 'no-viaja',
      contentType: 'image/jpeg',
      bytes: 256,
      sha256: '0'.repeat(64),
      state: 'pendiente_subida',
      createdAt: new Date(),
      width: null,
      height: null,
      blurhash: null,
      failure: null,
      processedVersion: null,
    };
    const permission = await storage.signUpload(photo, new Date(Date.now() + 300000));
    const url = new URL(permission.url);
    expect(url.pathname).toBe(`/fotos-privadas/cuarentena/${photo.id}`);
    expect(url.searchParams.get('X-Amz-SignedHeaders')).toContain('if-none-match');
    expect(url.searchParams.get('X-Amz-SignedHeaders')).toContain('content-length');
    expect(url.searchParams.get('X-Amz-SignedHeaders')).toContain('content-type');
    expect(Number(url.searchParams.get('X-Amz-Expires'))).toBeLessThanOrEqual(300);
    expect(permission.headers).toMatchObject({
      'If-None-Match': '*',
      'Content-Length': '256',
      'Content-Type': 'image/jpeg',
    });
    expect(permission.url).not.toContain('no-viaja');
    storage.onModuleDestroy();
  });
});
