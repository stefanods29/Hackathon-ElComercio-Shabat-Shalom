import type { ObjectStore, UploadPermission } from '../application/ports.js';
import type { Photo } from '../domain/photo.js';

export class FakeObjectStore implements ObjectStore {
  readonly objects = new Map<string, { bytes: Uint8Array; contentType: string }>();
  async signUpload(photo: Photo, expiresAt: Date): Promise<UploadPermission> {
    return {
      url: `https://storage.invalid/cuarentena/${photo.id}`,
      headers: { 'Content-Type': photo.contentType, 'If-None-Match': '*' },
      expiresAt,
    };
  }
  async signRead(key: string): Promise<string> {
    return `https://storage.invalid/${key}?firma=prueba`;
  }
  async head(key: string) {
    const object = this.objects.get(key);
    return object ? { bytes: object.bytes.byteLength, contentType: object.contentType } : null;
  }
  async read(key: string, maxBytes: number): Promise<Uint8Array> {
    const object = this.objects.get(key);
    if (!object || object.bytes.byteLength > maxBytes) throw new Error('Objeto no disponible');
    return object.bytes;
  }
  async write(key: string, bytes: Uint8Array): Promise<void> {
    this.objects.set(key, { bytes, contentType: 'image/webp' });
  }
  async delete(key: string): Promise<void> {
    this.objects.delete(key);
  }
  async cleanup(id: string, keepVersion: string | null): Promise<void> {
    for (const key of this.objects.keys()) {
      if (
        key === `cuarentena/${id}` ||
        (key.startsWith(`procesadas/${id}/`) &&
          (!keepVersion || !key.startsWith(`procesadas/${id}/${keepVersion}/`)))
      )
        this.objects.delete(key);
    }
  }
}
