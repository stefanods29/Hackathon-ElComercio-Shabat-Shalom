import { ConsoleLogger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import type { NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module.js';
import { loadConfig, loadEnvFile } from './shared/config/app-config.js';

loadEnvFile();
const config = loadConfig();

const app = await NestFactory.create<NestExpressApplication>(AppModule, {
  logger: new ConsoleLogger({ json: config.NODE_ENV === 'production', prefix: 'vecinal' }),
});
app.disable('x-powered-by');
app.useBodyParser('json', { limit: '256kb' });
app.enableShutdownHooks();

await app.listen(config.PORT);
new ConsoleLogger('Bootstrap').log(`API escuchando en el puerto ${config.PORT}`);
