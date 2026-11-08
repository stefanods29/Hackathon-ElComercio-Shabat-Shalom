import { Module } from '@nestjs/common';
import { CONTACT_DIRECTORY } from './application/contact-directory.js';
import { KyselyContactDirectory } from './infrastructure/contact-directory.kysely.js';

/**
 * Contact lookup only. Other modules (and the workers process) import this module instead of the
 * whole Identity module, which also brings sign-in controllers and session use cases.
 */
@Module({
  providers: [{ provide: CONTACT_DIRECTORY, useClass: KyselyContactDirectory }],
  exports: [CONTACT_DIRECTORY],
})
export class IdentityContactsModule {}
