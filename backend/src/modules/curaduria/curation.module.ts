import { S3Client } from '@aws-sdk/client-s3';
import { Module } from '@nestjs/common';
import { APP_CONFIG, type AppConfig } from '../../shared/config/app-config.js';
import { CurationController } from './api/curation.controller.js';
import { EmergencyDirectories } from './application/emergency-directories.js';
import { DIRECTORY_VERSIONS, PUBLIC_CONTENT_PUBLISHER } from './application/ports.js';
import { DirectoryVersionRepository } from './infrastructure/directory-version.repository.js';
import { DisabledPublisher } from './infrastructure/disabled-publisher.js';
import { FilesystemPublisher } from './infrastructure/filesystem-publisher.js';
import { S3Publisher } from './infrastructure/s3-publisher.js';

/** Emergency directory curation from the operations console (Phase 2, Lot C, part 3). */
@Module({
  controllers: [CurationController],
  providers: [
    EmergencyDirectories,
    { provide: DIRECTORY_VERSIONS, useClass: DirectoryVersionRepository },
    {
      provide: PUBLIC_CONTENT_PUBLISHER,
      inject: [APP_CONFIG],
      useFactory: (config: AppConfig) => {
        if (config.CURATION_PUBLISH_DRIVER === 'filesystem')
          return new FilesystemPublisher(config.CURATION_PUBLIC_ROOT);
        if (config.CURATION_PUBLISH_DRIVER === 'disabled') return new DisabledPublisher();
        const client = new S3Client({
          endpoint: config.CURATION_ENDPOINT,
          region: config.CURATION_REGION,
          forcePathStyle: config.CURATION_FORCE_PATH_STYLE,
          credentials: {
            accessKeyId: config.CURATION_ACCESS_KEY_ID!,
            secretAccessKey: config.CURATION_SECRET_ACCESS_KEY!,
          },
          requestChecksumCalculation: 'WHEN_REQUIRED',
          responseChecksumValidation: 'WHEN_REQUIRED',
          maxAttempts: 2,
        });
        return new S3Publisher(client, config.CURATION_BUCKET!);
      },
    },
  ],
})
export class CurationModule {}
