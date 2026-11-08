import { NestFactory } from '@nestjs/core';
import { Logger } from '@nestjs/common';
import { setTimeout } from 'node:timers/promises';
import { metrics, trace } from '@opentelemetry/api';
import { AppModule } from '../../app.module.js';
import { loadConfig, loadEnvFile } from '../../shared/config/app-config.js';
import { ProcessPhotos } from './application/process-photos.js';
import { startTelemetry } from '../../shared/observability/telemetry.js';

loadEnvFile();
const config = loadConfig();
startTelemetry(config, 'vecinal-media-worker');
if (config.MEDIA_DRIVER !== 's3')
  throw new Error('El worker Media requiere almacenamiento S3 configurado');
const app = await NestFactory.createApplicationContext(AppModule, { logger: ['error'] });
const processor = app.get(ProcessPhotos);
let stopping = false;
process.once('SIGINT', () => {
  stopping = true;
});
process.once('SIGTERM', () => {
  stopping = true;
});
const batchArgument = process.argv.find((argument) => argument.startsWith('--batch='));
const batchLimit = process.argv.includes('--once')
  ? 1
  : batchArgument
    ? Number(batchArgument.split('=')[1])
    : null;
if (batchLimit !== null && (!Number.isInteger(batchLimit) || batchLimit < 1 || batchLimit > 500))
  throw new Error('El lote del worker debe estar entre 1 y 500');
let cycles = 0;
try {
  do {
    try {
      const span = trace.getTracer('vecinal.media').startSpan('media.worker.cycle');
      const started = performance.now();
      let processed: boolean;
      try {
        processed = await processor.next();
      } finally {
        metrics
          .getMeter('vecinal.media')
          .createHistogram('media.worker.duration', { unit: 's' })
          .record((performance.now() - started) / 1000);
        span.end();
      }
      cycles++;
      if (!processed && batchLimit !== null) break;
      if (!processed) await setTimeout(2000);
    } catch {
      // SDK exceptions may include signed URLs or keys; never print them.
      new Logger('MediaWorker').error(
        'No se pudo completar el procesamiento de fotos; se reintentará.',
      );
      if (batchLimit === null) await setTimeout(5000);
      else {
        process.exitCode = 1;
        break;
      }
    }
  } while (!stopping && (batchLimit === null || cycles < batchLimit));
} finally {
  await app.close();
}
