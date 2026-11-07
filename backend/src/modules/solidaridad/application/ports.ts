import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import type { Coordinates, Post, PostProps } from '../domain/post.js';

/** Repository port: the application does not know whether Postgres or memory is behind it. */
export interface PostRepository {
  /** Serializes quota checks and inserts by author, including retries with different keys. */
  lockAuthor(transaction: TransactionContext, authorId: string): Promise<void>;
  countByAuthorSince(
    transaction: TransactionContext,
    authorId: string,
    since: Date,
  ): Promise<{ count: number; oldest: Date | null }>;
  /** Inserts when the id does not exist. Returns `false` if it already existed (phone retry). */
  insertIfAbsent(transaction: TransactionContext, post: Post): Promise<boolean>;
  findById(transaction: TransactionContext, id: string): Promise<Post | null>;
  /**
   * Saves the changes only if the database still holds `previousVersion`.
   * Returns `false` if another neighbor changed it first (optimistic concurrency).
   */
  updateIfVersion(
    transaction: TransactionContext,
    post: Post,
    previousVersion: number,
  ): Promise<boolean>;
}

export const POST_REPOSITORY = Symbol('POST_REPOSITORY');

export interface NearbyCursor {
  /** Same rounded distance as the response, never the exact sorting distance. */
  readonly d: number;
  readonly id: string;
}

export interface NearbyQuery {
  readonly location: Coordinates;
  readonly radius: number;
  readonly limit: number;
  readonly zoneId: string;
  readonly now: Date;
  readonly cursor: NearbyCursor | null;
}

export interface NearbyPost {
  readonly post: PostProps;
  readonly distanceMeters: number;
}

export interface NearbyPage {
  readonly data: NearbyPost[];
  readonly nextCursor: NearbyCursor | null;
}

export interface NearbyPostReader {
  findNearby(query: NearbyQuery): Promise<NearbyPage>;
}

export const NEARBY_POST_READER = Symbol('NEARBY_POST_READER');

/** Who performs the action, as certified by the access token. */
export interface NeighborActor {
  readonly id: string;
  readonly zoneId: string | null;
  readonly trustLevel: number;
}
