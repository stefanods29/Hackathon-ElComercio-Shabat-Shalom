import { Global, Inject, Module, type OnApplicationShutdown } from '@nestjs/common';
import type { Kysely } from 'kysely';
import { APP_CONFIG } from '../config/app-config.js';
import { KYSELY } from './connection.js';
import {
  DATABASE_CONNECTION,
  connectDatabase,
  type DatabaseConnection,
} from './configured-connection.js';
import { UNIT_OF_WORK } from './unit-of-work.js';
import { KyselyUnitOfWork } from './unit-of-work.kysely.js';

@Global()
@Module({
  providers: [
    { provide: DATABASE_CONNECTION, inject: [APP_CONFIG], useFactory: connectDatabase },
    {
      provide: KYSELY,
      inject: [DATABASE_CONNECTION],
      useFactory: (connection: DatabaseConnection) => connection.db,
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
  constructor(@Inject(DATABASE_CONNECTION) private readonly connection: DatabaseConnection) {}

  async onApplicationShutdown(): Promise<void> {
    await this.connection.close();
  }
}
