import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import type { Post } from '../domain/post.js';

/** Repository port: the application does not know whether Postgres or memory is behind it. */
export interface PostRepository {
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

/** Who performs the action, as certified by the access token. */
export interface NeighborActor {
  readonly id: string;
  readonly zoneId: string | null;
  readonly trustLevel: number;
}
