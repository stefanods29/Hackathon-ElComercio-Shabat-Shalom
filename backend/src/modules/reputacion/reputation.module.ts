import { Module } from '@nestjs/common';
import { ReputationModeration } from './infrastructure/reputation-moderation.kysely.js';
import { ReputationPersonalData } from './infrastructure/reputation-personal-data.kysely.js';
import { DirectoryModule } from '../directorio/index.js';
import { IdentityModule } from '../identidad/index.js';
import { ReputationController } from './api/reputation.controller.js';
import { Endorsements } from './application/endorsements.js';
import {
  REPUTATION_REPOSITORY,
  REVIEW_PHOTO_READER,
  REVIEW_RISK_READER,
  type ReviewPhotoReader,
} from './application/ports.js';
import { RecalculateReputation } from './application/recalculate-reputation.js';
import { WriteReview } from './application/write-review.js';
import { KyselyReputationRepository } from './infrastructure/reputation.repository.kysely.js';

@Module({
  imports: [DirectoryModule, IdentityModule],
  controllers: [ReputationController],
  providers: [
    ReputationModeration,
    ReputationPersonalData,
    WriteReview,
    Endorsements,
    RecalculateReputation,
    { provide: REPUTATION_REPOSITORY, useClass: KyselyReputationRepository },
    { provide: REVIEW_RISK_READER, useExisting: REPUTATION_REPOSITORY },
    // C1 will bind this port to media/index.ts. Never accept an unverifiable file.
    {
      provide: REVIEW_PHOTO_READER,
      useValue: { findOwnedReadyFile: async () => null } satisfies ReviewPhotoReader,
    },
  ],
  exports: [REVIEW_RISK_READER],
})
export class ReputationModule {}
