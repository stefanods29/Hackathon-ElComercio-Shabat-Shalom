import { Module } from '@nestjs/common';
import { SolidarityModeration } from './infrastructure/solidarity-moderation.kysely.js';
import { SolidarityPersonalData } from './infrastructure/solidarity-personal-data.kysely.js';
import { PostsController } from './api/posts.controller.js';
import { POST_REPOSITORY, NEARBY_POST_READER } from './application/ports.js';
import { PublishPost } from './application/publish-post.js';
import { TakeFavor } from './application/take-favor.js';
import { CancelPost } from './application/cancel-post.js';
import { ResolveFavor } from './application/resolve-favor.js';
import { FindNearbyPosts } from './application/find-nearby-posts.js';
import { KyselyPostRepository } from './infrastructure/post.repository.kysely.js';

@Module({
  controllers: [PostsController],
  providers: [
    SolidarityModeration,
    SolidarityPersonalData,
    PublishPost,
    TakeFavor,
    CancelPost,
    ResolveFavor,
    FindNearbyPosts,
    { provide: POST_REPOSITORY, useClass: KyselyPostRepository },
    { provide: NEARBY_POST_READER, useExisting: POST_REPOSITORY },
  ],
})
export class SolidarityModule {}
