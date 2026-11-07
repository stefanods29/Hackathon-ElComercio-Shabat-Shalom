import type { INestApplication } from '@nestjs/common';
import type { NestExpressApplication } from '@nestjs/platform-express';
import { Test, type TestingModuleBuilder } from '@nestjs/testing';
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
  customize: (builder: TestingModuleBuilder) => TestingModuleBuilder = (builder) => builder,
): Promise<TestApp> {
  const config = testConfig({ DATABASE_URL: databaseUrl, ...overrides });
  const moduleRef = await customize(
    Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(APP_CONFIG)
      .useValue(config),
  ).compile();
  const app = moduleRef.createNestApplication<NestExpressApplication>({ logger: false });
  app.set('trust proxy', config.TRUST_PROXY_HOPS);
  await app.init();
  return { app, config };
}
