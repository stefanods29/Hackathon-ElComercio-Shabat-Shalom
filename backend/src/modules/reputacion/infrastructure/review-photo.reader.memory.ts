import type { OwnedReadyFile, ReviewPhotoReader } from '../application/ports.js';

interface TestFile extends OwnedReadyFile {
  readonly ownerId: string;
  readonly state: 'listo' | 'pendiente' | 'rechazado' | 'publicado';
}

export class InMemoryReviewPhotoReader implements ReviewPhotoReader {
  readonly files = new Map<string, TestFile>();

  async findOwnedReadyFile(fileId: string, ownerId: string): Promise<OwnedReadyFile | null> {
    const file = this.files.get(fileId);
    if (!file || file.ownerId !== ownerId || file.state !== 'listo') return null;
    return {
      id: file.id,
      purpose: file.purpose,
      width: file.width,
      height: file.height,
      blurhash: file.blurhash,
    };
  }
}
