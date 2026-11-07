import {
  ABANDONED_AFTER_SECONDS,
  type IdempotencyStore,
  type IdempotentRequest,
  type ReservationResult,
} from './idempotency-store.js';

interface StoredEntry {
  fingerprint: string;
  status: 'in_progress' | 'completed';
  httpStatus: number | null;
  body: unknown;
  createdAt: Date;
  expiresAt: Date;
}

/** Same semantics as the Postgres adapter, for unit tests and development. */
export class InMemoryIdempotencyStore implements IdempotencyStore {
  private readonly entries = new Map<string, StoredEntry>();

  constructor(private readonly retentionHours = 168) {}

  async reserve(request: IdempotentRequest, now: Date): Promise<ReservationResult> {
    const mapKey = this.mapKey(request.scope, request.key);
    const existing = this.entries.get(mapKey);
    const expired = existing && existing.expiresAt.getTime() <= now.getTime();
    const abandoned =
      existing?.status === 'in_progress' &&
      now.getTime() - existing.createdAt.getTime() > ABANDONED_AFTER_SECONDS * 1000;

    if (!existing || expired || (abandoned && existing.fingerprint === request.fingerprint)) {
      this.entries.set(mapKey, {
        fingerprint: request.fingerprint,
        status: 'in_progress',
        httpStatus: null,
        body: null,
        createdAt: now,
        expiresAt: new Date(now.getTime() + this.retentionHours * 3_600_000),
      });
      return { kind: 'new' };
    }
    if (existing.fingerprint !== request.fingerprint) return { kind: 'fingerprint_mismatch' };
    if (existing.status === 'completed' && existing.httpStatus !== null) {
      return { kind: 'replay', httpStatus: existing.httpStatus, body: existing.body };
    }
    return { kind: 'in_progress' };
  }

  async complete(scope: string, key: string, httpStatus: number, body: unknown): Promise<void> {
    const entry = this.entries.get(this.mapKey(scope, key));
    if (entry) {
      entry.status = 'completed';
      entry.httpStatus = httpStatus;
      entry.body = structuredClone(body);
    }
  }

  async release(scope: string, key: string): Promise<void> {
    this.entries.delete(this.mapKey(scope, key));
  }

  private mapKey(scope: string, key: string): string {
    return `${scope}\u0000${key}`;
  }
}
