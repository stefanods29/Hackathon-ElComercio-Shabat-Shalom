import { ConsoleLogger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { loadConfig, loadEnvFile } from '../shared/config/app-config.js';
import { WorkersModule } from './workers.module.js';

loadEnvFile();
const config = loadConfig();
const app = await NestFactory.createApplicationContext(WorkersModule, {
  logger: new ConsoleLogger({ json: config.NODE_ENV === 'production', prefix: 'vecinal-workers' }),
});
app.enableShutdownHooks();
