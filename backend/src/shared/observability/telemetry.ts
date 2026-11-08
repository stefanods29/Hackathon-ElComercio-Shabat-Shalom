import { NodeSDK } from '@opentelemetry/sdk-node';
import { resourceFromAttributes } from '@opentelemetry/resources';
import { PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-http';
import { BatchLogRecordProcessor } from '@opentelemetry/sdk-logs';
import { OTLPLogExporter } from '@opentelemetry/exporter-logs-otlp-http';
import { logs, SeverityNumber } from '@opentelemetry/api-logs';
import * as Sentry from '@sentry/node';
import { Logger } from '@nestjs/common';
import type { AppConfig } from '../config/app-config.js';
import { errorCategory, privateEvent, safeRoute } from './privacy.js';

let sdk: NodeSDK | undefined;
let sentryEnabled = false;
export function startTelemetry(config: AppConfig, serviceName = 'vecinal-api'): void {
  if (config.OTEL_EXPORTER_OTLP_ENDPOINT) {
    const base = config.OTEL_EXPORTER_OTLP_ENDPOINT.replace(/\/$/, '');
    sdk = new NodeSDK({
      autoDetectResources: false,
      instrumentations: [],
      logRecordProcessors: [
        new BatchLogRecordProcessor({
          exporter: new OTLPLogExporter({ url: `${base}/v1/logs`, timeoutMillis: 5000 }),
        }),
      ],
      resource: resourceFromAttributes({
        'service.name': serviceName,
        'deployment.environment.name': config.APP_ENVIRONMENT,
      }),
      traceExporter: new OTLPTraceExporter({ url: `${base}/v1/traces`, timeoutMillis: 5000 }),
      metricReaders: [
        new PeriodicExportingMetricReader({
          exportIntervalMillis: 30000,
          exporter: new OTLPMetricExporter({ url: `${base}/v1/metrics`, timeoutMillis: 5000 }),
        }),
      ],
    });
    sdk.start();
  }
  if (config.SENTRY_DSN) {
    Sentry.init({
      dsn: config.SENTRY_DSN,
      environment: config.APP_ENVIRONMENT,
      dataCollection: {
        userInfo: false,
        cookies: false,
        httpHeaders: false,
        httpBodies: [],
        urlQueryParams: false,
        databaseQueryData: false,
        queues: false,
        stackFrameVariables: false,
        frameContextLines: 0,
      },
      defaultIntegrations: false,
      enableOpenTelemetrySetup: false,
      enableRuntimeChannelInjection: false,
      maxBreadcrumbs: 0,
      tracesSampleRate: 0,
      beforeSend: privateEvent,
      beforeSendTransaction: () => null,
    });
    sentryEnabled = true;
  }
}
export function reportServerFailure(error: unknown, route: unknown): void {
  logs.getLogger('vecinal').emit({
    severityNumber: SeverityNumber.ERROR,
    body: 'request_failed',
    attributes: { 'http.route': safeRoute(route), 'error.type': errorCategory(error) },
  });
  if (sentryEnabled)
    Sentry.captureEvent(privateEvent({ exception: { values: [{ type: errorCategory(error) }] } }));
  new Logger('Telemetry').error(
    JSON.stringify({
      event: 'request_failed',
      route: safeRoute(route),
      category: errorCategory(error),
    }),
  );
}
export async function stopTelemetry(): Promise<void> {
  await sdk?.shutdown();
  if (sentryEnabled) await Sentry.close(2000);
  sdk = undefined;
  sentryEnabled = false;
}
