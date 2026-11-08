import {
  Injectable,
  type CallHandler,
  type ExecutionContext,
  type NestInterceptor,
  type OnApplicationShutdown,
} from '@nestjs/common';
import { metrics, SpanStatusCode, trace } from '@opentelemetry/api';
import { type Observable, catchError, finalize, throwError } from 'rxjs';
import type { Request, Response } from 'express';
import { safeRoute } from './privacy.js';
import { stopTelemetry } from './telemetry.js';

@Injectable()
export class TelemetryInterceptor implements NestInterceptor, OnApplicationShutdown {
  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const http = context.switchToHttp();
    const request = http.getRequest<Request>();
    const response = http.getResponse<Response>();
    const method = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS'].includes(
      request.method,
    )
      ? request.method
      : 'OTHER';
    const attributes = {
      'http.route': safeRoute(request.route?.path),
      'http.request.method': method,
    };
    const span = trace.getTracer('vecinal.http').startSpan('http.request', { attributes });
    const started = performance.now();
    let failed = false;
    return next.handle().pipe(
      catchError((error: unknown) => {
        failed = true;
        span.setStatus({ code: SpanStatusCode.ERROR });
        return throwError(() => error);
      }),
      finalize(() => {
        const status = failed ? 'error' : String(Math.floor(response.statusCode / 100)) + 'xx';
        const data = { ...attributes, outcome: status };
        metrics
          .getMeter('vecinal.http')
          .createHistogram('http.server.duration', { unit: 's' })
          .record((performance.now() - started) / 1000, data);
        metrics.getMeter('vecinal.http').createCounter('http.server.requests').add(1, data);
        span.setAttribute('outcome', status);
        span.end();
      }),
    );
  }
  async onApplicationShutdown(): Promise<void> {
    await stopTelemetry();
  }
}
