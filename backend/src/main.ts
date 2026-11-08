import { ConsoleLogger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import type { NestExpressApplication } from '@nestjs/platform-express';
import type { NextFunction, Request, Response } from 'express';
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

// Phase 2, Lot C: the operations console runs in a browser on another origin (section 9.5).
if (config.CONSOLE_ORIGINS.length > 0) {
  app.enableCors({
    origin: config.CONSOLE_ORIGINS,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
    allowedHeaders: ['Authorization', 'Content-Type', 'Idempotency-Key', 'x-request-id'],
    exposedHeaders: ['Idempotent-Replayed', 'Retry-After', 'x-request-id'],
    credentials: false,
    maxAge: 600,
  });
}

// Sessions and operational data must never stay in a browser or proxy cache.
const noStorePrefixes = ['/v1/auth', '/v1/operacion', '/v1/moderacion', '/v1/avisos-urgentes'];
app.use((request: Request, response: Response, next: NextFunction) => {
  if (noStorePrefixes.some((prefix) => request.path.startsWith(prefix))) {
    response.setHeader('Cache-Control', 'no-store');
  }
  next();
});
app.enableShutdownHooks();

await app.listen(config.PORT);
new ConsoleLogger('Bootstrap', { json: true }).log({ evento: 'api.iniciada', puerto: config.PORT });
