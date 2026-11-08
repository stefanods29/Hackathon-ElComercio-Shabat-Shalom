import { ConsoleLogger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import type { NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module.js';
import { loadConfig, loadEnvFile } from './shared/config/app-config.js';
import { startTelemetry } from './shared/observability/telemetry.js';

loadEnvFile();
const config = loadConfig();
startTelemetry(config);

const app = await NestFactory.create<NestExpressApplication>(AppModule, {
  logger: new ConsoleLogger({ json: true, prefix: 'vecinal' }),
});
app.disable('x-powered-by');
app.set('trust proxy', config.TRUST_PROXY_HOPS);
app.useBodyParser('json', { limit: '256kb' });
app.enableShutdownHooks();

await app.listen(config.PORT);
new ConsoleLogger('Bootstrap', { json: true }).log({ evento: 'api.iniciada', puerto: config.PORT });
