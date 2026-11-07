import { Inject, Injectable } from '@nestjs/common';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { BusinessRuleViolation, ResourceNotFound } from '../../../shared/domain/errors.js';
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
      this.clock.now(),
    );

    return this.unitOfWork.run(async (transaction) => {
      const created = await this.posts.insertIfAbsent(transaction, post);
      if (created) {
        await this.outbox.record(transaction, 'solidaridad', post.pullEvents());
        return { post: post.snapshot(), created: true };
      }
      const existing = await this.posts.findById(transaction, command.id);
      if (!existing) {
        throw new ResourceNotFound('la publicación', command.id);
      }
      if (existing.snapshot().authorId !== actor.id) {
        // Someone else already uses the id: we do not reveal its content.
        throw new BusinessRuleViolation(
          'id_en_uso',
          'Ese id ya está en uso. Genera uno nuevo en el celular.',
          'conflict',
        );
      }
      return { post: existing.snapshot(), created: false };
    });
  }
}
