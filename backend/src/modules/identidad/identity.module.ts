import { Module } from '@nestjs/common';
import { SessionsController } from './api/sessions.controller.js';
import { IssueCredentials } from './application/issue-credentials.js';
import { USER_REPOSITORY } from './application/ports.js';
import { KyselyUserRepository } from './infrastructure/user.repository.kysely.js';

@Module({
  controllers: [SessionsController],
  providers: [IssueCredentials, { provide: USER_REPOSITORY, useClass: KyselyUserRepository }],
})
export class IdentityModule {}
