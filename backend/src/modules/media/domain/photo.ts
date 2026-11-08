export const MAX_PHOTO_BYTES = 2 * 1024 * 1024;
export const MAX_PHOTO_PIXELS = 20_000_000;
export const PHOTO_UPLOAD_SECONDS = 300;
export const PHOTO_LEASE_SECONDS = 300;
export const MAX_PROCESSING_ATTEMPTS = 3;
export type PhotoContentType = 'image/jpeg' | 'image/png' | 'image/webp';
export type PhotoState =
  'pendiente_subida' | 'en_cola' | 'procesando' | 'listo' | 'rechazado' | 'eliminado';

export interface Photo {
  readonly id: string;
  readonly ownerId: string;
  readonly zoneId: string;
  readonly contentType: PhotoContentType;
  readonly bytes: number;
  readonly sha256: string;
  readonly state: PhotoState;
  readonly createdAt: Date;
  readonly width: number | null;
  readonly height: number | null;
  readonly blurhash: string | null;
  readonly failure: string | null;
  readonly processedVersion: string | null;
}

export function photoKeys(id: string, version = id) {
  return {
    original: `cuarentena/${id}`,
    image: `procesadas/${id}/${version}/principal.webp`,
    thumbnail: `procesadas/${id}/${version}/miniatura.webp`,
  };
}

export function samePhoto(
  left: Photo,
  right: Pick<Photo, 'bytes' | 'sha256' | 'contentType'>,
): boolean {
  return (
    left.bytes === right.bytes &&
    left.sha256 === right.sha256 &&
    left.contentType === right.contentType
  );
}

export class InvalidPhoto extends Error {
  constructor(readonly reason: 'imagen_invalida' | 'contenido_distinto') {
    super(reason);
  }
}
