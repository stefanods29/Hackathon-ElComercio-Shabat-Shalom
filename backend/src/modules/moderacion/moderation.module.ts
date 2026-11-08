import { Module } from '@nestjs/common';
import { PublicationPolicy } from '../../shared/moderation/publication-policy.js';
import { IdentityModule } from '../identidad/index.js';
import { ModerationController } from './api/moderation.controller.js';
import { ImageModerationRegistry } from './application/image-moderation-registry.js';
import { DecideCase } from './application/decide-case.js';
import { ModerationEvents } from './application/moderation-events.js';
import { ModerationJobs } from './application/moderation-jobs.js';
import { ModerationPersonalData } from './infrastructure/moderation-personal-data.kysely.js';
import {
  IS_SUSPENDED,
  ModerationPolicyRegistration,
} from './application/moderation-policy-registration.js';
import { IMAGE_MODERATION, MODERATION_STORE } from './application/ports.js';
import { ReadModeration } from './application/read-moderation.js';
import { ReportContent } from './application/report-content.js';
import { ScreenContent } from './application/screen-content.js';
import { KyselyModerationStore } from './infrastructure/moderation.store.kysely.js';

@Module({
  imports: [IdentityModule],
  controllers: [ModerationController],
  providers: [
    ModerationPersonalData,
    ModerationEvents,
    ModerationJobs,
    ModerationPolicyRegistration,
    ReportContent,
    DecideCase,
    ReadModeration,
    ScreenContent,
    ImageModerationRegistry,
    { provide: MODERATION_STORE, useClass: KyselyModerationStore },
    // The media owner can replace this port without exposing storage or private URLs.
    { provide: IMAGE_MODERATION, useExisting: ImageModerationRegistry },
    {
      provide: IS_SUSPENDED,
      inject: [PublicationPolicy],
      useFactory: (policy: PublicationPolicy) => policy.isSuspended.bind(policy),
    },
  ],
  exports: [IS_SUSPENDED, IMAGE_MODERATION, ImageModerationRegistry],
})
export class ModerationModule {}
