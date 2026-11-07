/**
 * Port of the idempotency key store (`Idempotency-Key` header).
 * Guarantees that a retry from the phone never runs the same action twice.
 */
export interface IdempotentRequest {
  /** Who makes the request: two users can use the same key without colliding. */
  readonly scope: string;
  readonly key: string;
  readonly method: string;
  readonly path: string;
  /** SHA-256 of method, path and body: detects a key reused with different content. */
  readonly fingerprint: string;
}

export type ReservationResult =
  | { readonly kind: 'new' }
  | { readonly kind: 'replay'; readonly httpStatus: number; readonly body: unknown }
  | { readonly kind: 'in_progress' }
  | { readonly kind: 'fingerprint_mismatch' };

export interface IdempotencyStore {
  reserve(request: IdempotentRequest, now: Date): Promise<ReservationResult>;
  complete(scope: string, key: string, httpStatus: number, body: unknown): Promise<void>;
  /** Releases the reservation after a transient error so the retry runs again. */
  release(scope: string, key: string): Promise<void>;
}

export const IDEMPOTENCY_STORE = Symbol('IDEMPOTENCY_STORE');

/** An "in progress" reservation older than this is considered abandoned (e.g. the API restarted). */
export const ABANDONED_AFTER_SECONDS = 60;
