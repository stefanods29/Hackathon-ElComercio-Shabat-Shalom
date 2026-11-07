import { Inject, Injectable } from '@nestjs/common';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import {
  BusinessRuleViolation,
  ResourceNotFound,
  VersionConflict,
} from '../../../shared/domain/errors.js';
import { OUTBOX_WRITER, type OutboxWriter } from '../../../shared/outbox/outbox.js';
import type { PostProps } from '../domain/post.js';
import { POST_REPOSITORY, type PostRepository, type NeighborActor } from './ports.js';

export interface CancelPostCommand {
  readonly postId: string;
  readonly seenVersion: number;
}

@Injectable()
export class CancelPost {
  constructor(
    @Inject(UNIT_OF_WORK) private readonly unitOfWork: UnitOfWork,
    @Inject(POST_REPOSITORY) private readonly posts: PostRepository,
    @Inject(OUTBOX_WRITER) private readonly outbox: OutboxWriter,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  async execute(command: CancelPostCommand, actor: NeighborActor): Promise<PostProps> {
    return this.unitOfWork.run(async (transaction) => {
      const post = await this.posts.findById(transaction, command.postId);
      if (!post) throw new ResourceNotFound('la publicación', command.postId);
      if (post.snapshot().zoneId !== actor.zoneId)
        throw new BusinessRuleViolation(
          'fuera_de_tu_zona',
          'Solo puedes cancelar publicaciones de tu zona.',
          'forbidden',
        );
      const previousVersion = post.version;
      if (post.cancel(actor.id, command.seenVersion, this.clock.now()) === 'already_cancelled')
        return post.snapshot();
      if (!(await this.posts.updateIfVersion(transaction, post, previousVersion))) {
        const latest = await this.posts.findById(transaction, command.postId);
        if (!latest) throw new ResourceNotFound('la publicación', command.postId);
        const latestVersion = latest.version;
        if (latest.cancel(actor.id, command.seenVersion, this.clock.now()) === 'already_cancelled')
          return latest.snapshot();
        throw new VersionConflict(command.seenVersion, latestVersion);
      }
      await this.outbox.record(transaction, 'solidaridad', post.pullEvents());
      return post.snapshot();
    });
  }
}
