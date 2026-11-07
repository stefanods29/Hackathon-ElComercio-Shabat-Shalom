import { Module } from '@nestjs/common';
import { PostsController } from './api/posts.controller.js';
import { POST_REPOSITORY } from './application/ports.js';
import { PublishPost } from './application/publish-post.js';
import { TakeFavor } from './application/take-favor.js';
import { KyselyPostRepository } from './infrastructure/post.repository.kysely.js';

@Module({
  controllers: [PostsController],
  providers: [PublishPost, TakeFavor, { provide: POST_REPOSITORY, useClass: KyselyPostRepository }],
})
export class SolidarityModule {}
