import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import type { PostRepository } from '../application/ports.js';
import { Post, type PostProps } from '../domain/post.js';

/** Test double with the same semantics as the Postgres repository. */
export class InMemoryPostRepository implements PostRepository {
  private readonly rows = new Map<string, PostProps>();

  async insertIfAbsent(_transaction: TransactionContext, post: Post): Promise<boolean> {
    if (this.rows.has(post.id)) return false;
    this.rows.set(post.id, post.snapshot());
    return true;
  }

  async findById(_transaction: TransactionContext, id: string): Promise<Post | null> {
    const row = this.rows.get(id);
    return row ? Post.restore(row) : null;
  }

  async updateIfVersion(
    _transaction: TransactionContext,
    post: Post,
    previousVersion: number,
  ): Promise<boolean> {
    const current = this.rows.get(post.id);
    if (!current || current.version !== previousVersion) return false;
    this.rows.set(post.id, post.snapshot());
    return true;
  }

  /** Simulates another neighbor changing the row (to test the write race). */
  force(props: PostProps): void {
    this.rows.set(props.id, props);
  }
}
