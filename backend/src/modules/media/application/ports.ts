import type { Photo } from '../domain/photo.js';

export interface UploadPermission {
  readonly url: string;
  readonly headers: Readonly<Record<string, string>>;
  readonly expiresAt: Date;
}

export interface ObjectStore {
  signUpload(photo: Photo, expiresAt: Date): Promise<UploadPermission>;
  signRead(key: string, expiresAt: Date): Promise<string>;
  head(key: string): Promise<{ bytes: number; contentType: string } | null>;
  read(key: string, maxBytes: number): Promise<Uint8Array>;
  write(key: string, bytes: Uint8Array): Promise<void>;
  delete(key: string): Promise<void>;
  cleanup(id: string, keepVersion: string | null): Promise<void>;
}

export interface ProcessedPhoto {
  readonly image: Uint8Array;
  readonly thumbnail: Uint8Array;
  readonly width: number;
  readonly height: number;
  readonly blurhash: string;
}

export interface PhotoProcessor {
  process(bytes: Uint8Array): Promise<ProcessedPhoto>;
}

export interface PhotoClaim {
  readonly photo: Photo;
  readonly leaseId: string;
}
export interface PhotoRepository {
  reserve(photo: Photo): Promise<Photo>;
  findOwned(id: string, ownerId: string): Promise<Photo | null>;
  enqueue(id: string, ownerId: string): Promise<void>;
  allowUploadUntil(id: string, ownerId: string, expiresAt: Date): Promise<boolean>;
  remove(id: string, ownerId: string): Promise<void>;
  claim(): Promise<PhotoClaim | null>;
  finish(claim: PhotoClaim, result: ProcessedPhoto): Promise<boolean>;
  fail(claim: PhotoClaim, reason: string, permanent: boolean): Promise<void>;
  claimCleanup(): Promise<PhotoClaim | null>;
  finishCleanup(claim: PhotoClaim): Promise<void>;
}

export const PHOTO_REPOSITORY = Symbol('PHOTO_REPOSITORY');
export const OBJECT_STORE = Symbol('OBJECT_STORE');
export const PHOTO_PROCESSOR = Symbol('PHOTO_PROCESSOR');
