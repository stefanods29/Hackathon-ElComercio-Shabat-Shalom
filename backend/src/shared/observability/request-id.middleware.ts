import { Injectable, Logger, type NestMiddleware } from '@nestjs/common';
import type { NextFunction, Request, Response } from 'express';
import { newId } from '../domain/ids.js';

export type CorrelatedRequest = Request & { requestId?: string };

export function requestIdFor(value: unknown): string {
  return typeof value === 'string' && /^[A-Za-z0-9._:-]{1,128}$/.test(value) ? value : newId();
}

export function problemInstance(request: Pick<Request, 'originalUrl'>, requestId: string): string {
  return request.originalUrl.split('?')[0] + '#requestId=' + encodeURIComponent(requestId);
}

@Injectable()
export class HttpRequestLogger {
  private readonly logger = new Logger('Http');

  record(entry: {
    requestId: string;
    metodo: string;
    ruta: string;
    estado: number;
    duracionMs: number;
  }): void {
    this.logger.log({ evento: 'http.solicitud_completada', ...entry });
  }
}

@Injectable()
export class RequestIdMiddleware implements NestMiddleware {
  constructor(private readonly logger: HttpRequestLogger) {}

  use(request: CorrelatedRequest, response: Response, next: NextFunction): void {
    const requestId = requestIdFor(request.headers['x-request-id']);
    request.requestId = requestId;
    response.setHeader('x-request-id', requestId);
    const started = performance.now();
    let recorded = false;
    const record = (status: number) => {
      if (recorded) return;
      recorded = true;
      // Route templates only: no query, arbitrary path, headers, request body or response body.
      const route: unknown = request.route?.path;
      this.logger.record({
        requestId,
        metodo: request.method,
        ruta: typeof route === 'string' ? route : '(sin ruta)',
        estado: status,
        duracionMs: Math.round((performance.now() - started) * 1000) / 1000,
      });
    };
    response.once('finish', () => record(response.statusCode));
    response.once('close', () => record(response.writableFinished ? response.statusCode : 499));
    next();
  }
}
