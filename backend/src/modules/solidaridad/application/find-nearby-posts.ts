import { Inject, Injectable } from '@nestjs/common';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { BusinessRuleViolation } from '../../../shared/domain/errors.js';
import type { Coordinates } from '../domain/post.js';
import { decodeNearbyCursor, encodeNearbyCursor } from './nearby-cursor.js';
import {
  NEARBY_POST_READER,
  type NearbyPostReader,
  type NearbyPost,
  type NeighborActor,
} from './ports.js';

export interface FindNearbyPostsCommand {
  readonly location: Coordinates;
  readonly radius: number;
  readonly limit: number;
  readonly cursor?: string;
}

@Injectable()
export class FindNearbyPosts {
  constructor(
    @Inject(NEARBY_POST_READER) private readonly posts: NearbyPostReader,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  async execute(
    command: FindNearbyPostsCommand,
    actor: NeighborActor,
  ): Promise<{ data: NearbyPost[]; nextCursor: string | null }> {
    if (!actor.zoneId)
      throw new BusinessRuleViolation(
        'sin_zona',
        'Elige tu zona antes de consultar el muro.',
        'forbidden',
      );
    const page = await this.posts.findNearby({
      location: command.location,
      radius: command.radius,
      limit: command.limit,
      cursor: command.cursor ? decodeNearbyCursor(command.cursor) : null,
      zoneId: actor.zoneId,
      now: this.clock.now(),
    });
    return {
      data: page.data,
      nextCursor: page.nextCursor ? encodeNearbyCursor(page.nextCursor) : null,
    };
  }
}
