import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import type { EmergencyDirectory } from '../domain/emergency-directory.js';

/**
 * Public content served by the CDN (`emergencia/<archivo>` and `emergencia/indice.json`).
 * Adapters: the local CDN folder for development, and the cloud storage of Phase 1 (Lot C).
 */
export interface PublicContentPublisher {
  readonly enabled: boolean;
  /** Null when the object does not exist. */
  read(relativePath: string): Promise<Buffer | null>;
  write(relativePath: string, body: Buffer, contentType: string): Promise<void>;
}

export const PUBLIC_CONTENT_PUBLISHER = Symbol('PUBLIC_CONTENT_PUBLISHER');

export interface DirectoryVersionRecord {
  readonly archivo: string;
  readonly version: number;
  readonly contenido: EmergencyDirectory;
  readonly sha256: string;
  readonly bytes: number;
  readonly publicadoPor: string;
  readonly publicadoEn: Date;
}

/** Audit of every published version; also the concurrency check between curators. */
export interface DirectoryVersionStore {
  /** Serializes publications of the same file until the transaction ends. */
  lock(transaction: TransactionContext, archivo: string): Promise<void>;
  latest(transaction: TransactionContext, archivo: string): Promise<number | null>;
  insert(transaction: TransactionContext, record: DirectoryVersionRecord): Promise<void>;
}

export const DIRECTORY_VERSIONS = Symbol('DIRECTORY_VERSIONS');
