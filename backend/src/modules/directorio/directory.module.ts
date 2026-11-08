import { ReputationAggregatesHandler } from './application/reputation-aggregates-handler.js';
import {
  DIRECTORY_RANKING_STORE,
  DIRECTORY_SERVICE_READER,
} from './application/reputation-ports.js';
import { KyselyDirectoryReputationStore } from './infrastructure/reputation.store.kysely.js';
import { Module } from '@nestjs/common';
import { DirectoryController } from './api/directory.controller.js';
import { FindServices } from './application/find-services.js';
import { SERVICE_SEARCH_READER } from './application/search-ports.js';
import { KyselyServiceSearchReader } from './infrastructure/service-search.reader.kysely.js';
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
    FindServices,
    { provide: SERVICE_SEARCH_READER, useClass: KyselyServiceSearchReader },
    ZoneChangedHandler,
    ReputationAggregatesHandler,
    { provide: DIRECTORY_RANKING_STORE, useClass: KyselyDirectoryReputationStore },
    { provide: DIRECTORY_SERVICE_READER, useExisting: DIRECTORY_RANKING_STORE },
    { provide: DIRECTORY_REPOSITORY, useClass: KyselyDirectoryRepository },
  ],
  exports: [DIRECTORY_SERVICE_READER],
})
export class DirectoryModule {}
