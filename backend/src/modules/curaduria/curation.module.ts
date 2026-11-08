import { Module } from '@nestjs/common';
import { APP_CONFIG, type AppConfig } from '../../shared/config/app-config.js';
import { CurationController } from './api/curation.controller.js';
import { EmergencyDirectories } from './application/emergency-directories.js';
import { DIRECTORY_VERSIONS, PUBLIC_CONTENT_PUBLISHER } from './application/ports.js';
import { DirectoryVersionRepository } from './infrastructure/directory-version.repository.js';
import { DisabledPublisher } from './infrastructure/disabled-publisher.js';
import { FilesystemPublisher } from './infrastructure/filesystem-publisher.js';

/** Emergency directory curation from the operations console (Phase 2, Lot C, part 3). */
@Module({
  controllers: [CurationController],
  providers: [
    EmergencyDirectories,
    { provide: DIRECTORY_VERSIONS, useClass: DirectoryVersionRepository },
    {
      provide: PUBLIC_CONTENT_PUBLISHER,
      inject: [APP_CONFIG],
      useFactory: (config: AppConfig) =>
        config.CURATION_PUBLISH_DRIVER === 'filesystem'
          ? new FilesystemPublisher(config.CURATION_PUBLIC_ROOT)
          : new DisabledPublisher(),
    },
  ],
})
export class CurationModule {}
