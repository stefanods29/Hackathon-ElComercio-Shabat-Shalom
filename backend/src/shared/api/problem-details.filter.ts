import { type ArgumentsHost, Catch, type ExceptionFilter, Logger } from '@nestjs/common';
import type { Response } from 'express';
import {
  type CorrelatedRequest,
  problemInstance,
  requestIdFor,
} from '../observability/request-id.middleware.js';
import {
  PROBLEM_CONTENT_TYPE,
  PrebuiltProblem,
  toProblemDetails,
  type ProblemDetails,
} from './problem-details.js';
import { reportServerFailure } from '../observability/telemetry.js';

/** Every error response goes out as `application/problem+json` (RFC 9457). */
@Catch()
export class ProblemDetailsFilter implements ExceptionFilter {
  private readonly logger = new Logger('Errors');

  catch(error: unknown, host: ArgumentsHost): void {
    const http = host.switchToHttp();
    const response = http.getResponse<Response>();
    const request = http.getRequest<CorrelatedRequest>();
    const requestId = request.requestId ?? requestIdFor(undefined);
    const instance = problemInstance(request, requestId);

    const base =
      error instanceof PrebuiltProblem ? error.problem : toProblemDetails(error, instance);
    const problem: ProblemDetails = { ...base, instance, requestId };

    if (problem.status >= 500) {
      this.logger.error({
        evento: 'http.error_interno',
        requestId,
        metodo: request.method,
        estado: problem.status,
      });
      reportServerFailure(error, request.route?.path);
    }

    if (response.headersSent) {
      return;
    }
    const retryAfter = problem.reintentarEnSegundos;
    if (typeof retryAfter === 'number' && Number.isFinite(retryAfter)) {
      response.setHeader('Retry-After', String(Math.ceil(retryAfter)));
    }
    response
      .status(problem.status)
      .setHeader('x-request-id', requestId)
      .setHeader('content-type', `${PROBLEM_CONTENT_TYPE}; charset=utf-8`)
      .send(JSON.stringify(problem));
  }
}
