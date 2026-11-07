import { Inject, Injectable } from '@nestjs/common';
import { APP_CONFIG, type AppConfig } from '../../../shared/config/app-config.js';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import {
  BusinessRuleViolation,
  RateLimitExceeded,
  ResourceNotFound,
} from '../../../shared/domain/errors.js';
import { OUTBOX_WRITER, type OutboxWriter } from '../../../shared/outbox/outbox.js';
import {
  type Coordinates,
  MIN_TRUST_LEVEL_TO_PUBLISH,
  Post,
  type PostProps,
  type PostType,
} from '../domain/post.js';
import { type NeighborActor, POST_REPOSITORY, type PostRepository } from './ports.js';

export interface PublishPostCommand {
  readonly id: string;
  readonly type: PostType;
  readonly category: string;
  readonly title: string;
  readonly description?: string | null;
  readonly location?: Coordinates | null;
  readonly expiresAt?: Date | null;
}

export interface PublishPostResult {
  readonly post: PostProps;
  /** `false` when the phone retried and the post already existed: it is not duplicated. */
  readonly created: boolean;
}

/** "Publish on the wall" use case (third tap of the publishing flow). */
@Injectable()
export class PublishPost {
  constructor(
    @Inject(UNIT_OF_WORK) private readonly unitOfWork: UnitOfWork,
    @Inject(POST_REPOSITORY) private readonly posts: PostRepository,
    @Inject(OUTBOX_WRITER) private readonly outbox: OutboxWriter,
    @Inject(CLOCK) private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  async execute(command: PublishPostCommand, actor: NeighborActor): Promise<PublishPostResult> {
    if (actor.trustLevel < MIN_TRUST_LEVEL_TO_PUBLISH) {
      throw new BusinessRuleViolation(
        'nivel_de_confianza_insuficiente',
        'Para publicar en el muro primero confirma que vives en la zona.',
        'forbidden',
        { nivelActual: actor.trustLevel, nivelRequerido: MIN_TRUST_LEVEL_TO_PUBLISH },
      );
    }
    if (!actor.zoneId) {
      throw new BusinessRuleViolation(
        'sin_zona',
        'Elige tu zona antes de publicar en el muro.',
        'forbidden',
      );
    }
    const zoneId = actor.zoneId;
    return this.unitOfWork.run(async (transaction) => {
      await this.posts.lockAuthor(transaction, actor.id);
      const existing = await this.posts.findById(transaction, command.id);
      if (existing) return this.existingResult(existing, actor);
      const now = this.clock.now();
      const dayMilliseconds = 24 * 60 * 60_000;
      const usage = await this.posts.countByAuthorSince(
        transaction,
        actor.id,
        new Date(now.getTime() - dayMilliseconds),
      );
      if (usage.count >= this.config.MAX_POSTS_PER_DAY) {
        const retryAfter = Math.max(
          1,
          Math.ceil(
            ((usage.oldest?.getTime() ?? now.getTime()) + dayMilliseconds - now.getTime()) / 1000,
          ),
        );
        throw new RateLimitExceeded(
          'limite_diario_alcanzado',
          'Llegaste al límite de publicaciones de hoy. Podrás publicar de nuevo más tarde.',
          retryAfter,
        );
      }
      const post = Post.create(
        {
          id: command.id,
          authorId: actor.id,
          zoneId,
          type: command.type,
          category: command.category,
          title: command.title,
          description: command.description ?? null,
          location: command.location ?? null,
          expiresAt: command.expiresAt ?? null,
        },
        now,
      );
      const created = await this.posts.insertIfAbsent(transaction, post);
      if (created) {
        await this.outbox.record(transaction, 'solidaridad', post.pullEvents());
        return { post: post.snapshot(), created: true };
      }
      const concurrent = await this.posts.findById(transaction, command.id);
      if (!concurrent) {
        throw new ResourceNotFound('la publicación', command.id);
      }
      return this.existingResult(concurrent, actor);
    });
  }

  private existingResult(existing: Post, actor: NeighborActor): PublishPostResult {
    if (existing.snapshot().authorId !== actor.id) {
      // Someone else already uses the id: we do not reveal its content.
      throw new BusinessRuleViolation(
        'id_en_uso',
        'Ese id ya está en uso. Genera uno nuevo en el celular.',
        'conflict',
      );
    }
    return { post: existing.snapshot(), created: false };
  }
}
