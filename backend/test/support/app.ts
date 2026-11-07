import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { AppModule } from '../../src/app.module.js';
import { APP_CONFIG, type AppConfig } from '../../src/shared/config/app-config.js';
import { testConfig } from './config.js';

export interface TestApp {
  readonly app: INestApplication;
  readonly config: AppConfig;
}

/** Boots the full API (every module) against the test database. */
export async function createTestApp(
  databaseUrl: string,
  overrides: Partial<Record<string, string>> = {},
): Promise<TestApp> {
  const config = testConfig({ DATABASE_URL: databaseUrl, ...overrides });
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
    .overrideProvider(APP_CONFIG)
    .useValue(config)
    .compile();
  const app = moduleRef.createNestApplication({ logger: false });
  await app.init();
  return { app, config };
}
