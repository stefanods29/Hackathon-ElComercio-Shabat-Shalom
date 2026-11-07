import { type ArgumentsHost, Catch, type ExceptionFilter, Logger } from '@nestjs/common';
import type { Request, Response } from 'express';
import { PROBLEM_CONTENT_TYPE, PrebuiltProblem, toProblemDetails } from './problem-details.js';

/** Every error response goes out as `application/problem+json` (RFC 9457). */
@Catch()
export class ProblemDetailsFilter implements ExceptionFilter {
  private readonly logger = new Logger('Errors');

  catch(error: unknown, host: ArgumentsHost): void {
    const http = host.switchToHttp();
    const response = http.getResponse<Response>();
    const request = http.getRequest<Request>();

    const problem =
      error instanceof PrebuiltProblem
        ? error.problem
        : toProblemDetails(error, request.originalUrl);

    if (problem.status >= 500) {
      this.logger.error(
        `${request.method} ${request.originalUrl} → ${problem.status}`,
        error instanceof Error ? error.stack : String(error),
      );
    }

    if (response.headersSent) {
      return;
    }
    response
      .status(problem.status)
      .setHeader('content-type', `${PROBLEM_CONTENT_TYPE}; charset=utf-8`)
      .send(JSON.stringify(problem));
  }
}
