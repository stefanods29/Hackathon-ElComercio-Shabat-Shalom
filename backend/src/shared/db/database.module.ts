import { Global, Inject, Module, type OnApplicationShutdown } from '@nestjs/common';
import type { Kysely } from 'kysely';
import { APP_CONFIG, type AppConfig } from '../config/app-config.js';
import { KYSELY, createKysely } from './connection.js';
import { UNIT_OF_WORK } from './unit-of-work.js';
import { KyselyUnitOfWork } from './unit-of-work.kysely.js';

@Global()
@Module({
  providers: [
    {
      provide: KYSELY,
      inject: [APP_CONFIG],
      useFactory: (config: AppConfig) => createKysely(config.DATABASE_URL),
    },
    {
      provide: UNIT_OF_WORK,
      inject: [KYSELY],
      useFactory: (db: Kysely<unknown>) => new KyselyUnitOfWork(db),
    },
  ],
  exports: [KYSELY, UNIT_OF_WORK],
})
export class DatabaseModule implements OnApplicationShutdown {
  constructor(@Inject(KYSELY) private readonly db: Kysely<unknown>) {}

  async onApplicationShutdown(): Promise<void> {
    await this.db.destroy();
  }
}
