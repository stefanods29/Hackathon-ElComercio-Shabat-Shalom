import { Module } from '@nestjs/common';
import { S3Client } from '@aws-sdk/client-s3';
import { APP_CONFIG, type AppConfig } from '../../shared/config/app-config.js';
import { PhotosController } from './api/photos.controller.js';
import { ManagePhotos } from './application/manage-photos.js';
import { ProcessPhotos } from './application/process-photos.js';
import { OBJECT_STORE, PHOTO_REPOSITORY, PHOTO_PROCESSOR } from './application/ports.js';
import { PostgresPhotoRepository } from './infrastructure/photo.repository.js';
import { SharpPhotoProcessor } from './infrastructure/sharp-photo.processor.js';
import { S3ObjectStore } from './infrastructure/object-store.s3.js';
import { FakeObjectStore } from './infrastructure/object-store.fake.js';
import { DisabledObjectStore } from './infrastructure/object-store.disabled.js';

/** Private photo lifecycle. Processing is run by the separate Media worker. */
@Module({
  controllers: [PhotosController],
  providers: [
    ManagePhotos,
    ProcessPhotos,
    { provide: PHOTO_REPOSITORY, useClass: PostgresPhotoRepository },
    { provide: PHOTO_PROCESSOR, useClass: SharpPhotoProcessor },
    {
      provide: OBJECT_STORE,
      inject: [APP_CONFIG],
      useFactory: (config: AppConfig) => {
        if (config.MEDIA_DRIVER === 'fake') return new FakeObjectStore();
        if (config.MEDIA_DRIVER === 'disabled') return new DisabledObjectStore();
        const client = new S3Client({
          region: config.MEDIA_REGION,
          endpoint: config.MEDIA_ENDPOINT,
          forcePathStyle: config.MEDIA_FORCE_PATH_STYLE,
          requestChecksumCalculation: 'WHEN_REQUIRED',
          responseChecksumValidation: 'WHEN_REQUIRED',
          maxAttempts: 2,
          ...(config.MEDIA_ACCESS_KEY_ID
            ? {
                credentials: {
                  accessKeyId: config.MEDIA_ACCESS_KEY_ID,
                  secretAccessKey: config.MEDIA_SECRET_ACCESS_KEY!,
                },
              }
            : {}),
        });
        return new S3ObjectStore(client, config.MEDIA_BUCKET!);
      },
    },
  ],
  exports: [ManagePhotos, ProcessPhotos],
})
export class MediaModule {}
