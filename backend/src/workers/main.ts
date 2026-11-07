import { ConsoleLogger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { loadConfig, loadEnvFile } from '../shared/config/app-config.js';
import { WorkersModule } from './workers.module.js';

loadEnvFile();
loadConfig();
const app = await NestFactory.createApplicationContext(WorkersModule, {
  logger: new ConsoleLogger({ json: true, prefix: 'vecinal-workers' }),
});
app.enableShutdownHooks();
new ConsoleLogger('Bootstrap', { json: true }).log({ evento: 'workers.iniciados' });
