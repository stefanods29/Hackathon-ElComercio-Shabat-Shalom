import { generateKeyPairSync } from 'node:crypto';
import { type AppConfig, loadConfig } from '../../src/shared/config/app-config.js';

/** A new ES256 key for every test run. */
export function testPrivateKey(): string {
  return generateKeyPairSync('ec', { namedCurve: 'prime256v1' })
    .privateKey.export({ format: 'pem', type: 'pkcs8' })
    .toString();
}

/** Valid configuration for tests; `overrides` replaces specific variables. */
export function testConfig(overrides: Partial<Record<string, string>> = {}): AppConfig {
  return loadConfig({
    NODE_ENV: 'test',
    DATABASE_URL: 'postgres://usuario:clave@localhost:5432/vecinal',
    JWT_PRIVATE_KEY_PEM: testPrivateKey(),
    POWERSYNC_URL: 'http://localhost:8080',
    ENABLE_DEV_SESSION: 'true',
    OTP_PROVIDER: 'fake',
    OTP_HASH_SECRET: 'secreto-fijo-de-pruebas-para-hmac-otp',
    REFRESH_TOKEN_SECRET: 'secreto-fijo-de-pruebas-para-hmac-refresh',
    ...overrides,
  });
}
