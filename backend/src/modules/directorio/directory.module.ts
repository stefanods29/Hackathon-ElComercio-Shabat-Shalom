import { Module } from '@nestjs/common';
import { DirectoryController } from './api/directory.controller.js';
import { EditService } from './application/edit-service.js';
import { DIRECTORY_REPOSITORY } from './application/ports.js';
import { PublishService } from './application/publish-service.js';
import { ReadDirectory } from './application/read-directory.js';
import { SaveProvider } from './application/save-provider.js';
import { WithdrawService } from './application/withdraw-service.js';
import { ZoneChangedHandler } from './application/zone-changed-handler.js';
import { KyselyDirectoryRepository } from './infrastructure/directory.repository.kysely.js';

@Module({
  controllers: [DirectoryController],
  providers: [
    SaveProvider,
    PublishService,
    EditService,
    WithdrawService,
    ReadDirectory,
    ZoneChangedHandler,
    { provide: DIRECTORY_REPOSITORY, useClass: KyselyDirectoryRepository },
  ],
})
export class DirectoryModule {}
