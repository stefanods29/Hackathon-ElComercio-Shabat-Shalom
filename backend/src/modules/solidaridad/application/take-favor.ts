import { Inject, Injectable } from '@nestjs/common';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import {
  BusinessRuleViolation,
  ResourceNotFound,
  VersionConflict,
} from '../../../shared/domain/errors.js';
import { OUTBOX_WRITER, type OutboxWriter } from '../../../shared/outbox/outbox.js';
import { type PostProps, favorNotAvailable } from '../domain/post.js';
import { type NeighborActor, POST_REPOSITORY, type PostRepository } from './ports.js';

export interface TakeFavorCommand {
  readonly postId: string;
  /** Version the neighbor was looking at on the phone when tapping "Take". */
  readonly seenVersion: number;
}

/**
 * "Take a favor" use case. If two neighbors take it offline, the server decides:
 * the first to arrive wins and the second gets an explainable rejection (409).
 */
@Injectable()
export class TakeFavor {
  constructor(
    @Inject(UNIT_OF_WORK) private readonly unitOfWork: UnitOfWork,
    @Inject(POST_REPOSITORY) private readonly posts: PostRepository,
    @Inject(OUTBOX_WRITER) private readonly outbox: OutboxWriter,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  async execute(command: TakeFavorCommand, actor: NeighborActor): Promise<PostProps> {
    return this.unitOfWork.run(async (transaction) => {
      const post = await this.posts.findById(transaction, command.postId);
      if (!post) {
        throw new ResourceNotFound('la publicación', command.postId);
      }
      if (post.snapshot().zoneId !== actor.zoneId) {
        throw new BusinessRuleViolation(
          'fuera_de_tu_zona',
          'Solo puedes tomar favores de tu zona.',
          'forbidden',
        );
      }
      const previousVersion = post.version;
      const result = post.take(actor.id, command.seenVersion, this.clock.now());
      if (result === 'already_mine') {
        return post.snapshot();
      }
      const saved = await this.posts.updateIfVersion(transaction, post, previousVersion);
      if (!saved) {
        // Another neighbor won the race between the read and the write.
        const latest = await this.posts.findById(transaction, command.postId);
        const latestStatus = latest?.snapshot().status;
        if (latestStatus && latestStatus !== 'abierta') {
          throw favorNotAvailable(latestStatus);
        }
        throw new VersionConflict(command.seenVersion, latest?.version ?? previousVersion + 1);
      }
      await this.outbox.record(transaction, 'solidaridad', post.pullEvents());
      return post.snapshot();
    });
  }
}
