import type { ArgumentsHost } from '@nestjs/common';
import type { Response } from 'express';
import { RateLimitExceeded } from '../domain/errors.js';
import { ProblemDetailsFilter } from './problem-details.filter.js';
import { PrebuiltProblem, toProblemDetails } from './problem-details.js';

function createHost(response: Response): ArgumentsHost {
  return {
    switchToHttp: () => ({
      getResponse: () => response,
      getRequest: () => ({ method: 'POST', originalUrl: '/v1/auth/otp' }),
    }),
  } as ArgumentsHost;
}

describe('ProblemDetailsFilter', () => {
  it('agrega Retry-After también al repetir un problema ya construido', () => {
    const status = vi.fn().mockReturnThis();
    const setHeader = vi.fn().mockReturnThis();
    const response = {
      headersSent: false,
      status,
      setHeader,
      send: vi.fn().mockReturnThis(),
    } as unknown as Response;
    const problem = toProblemDetails(
      new RateLimitExceeded('demasiados_intentos', 'Espera un momento.', 42),
    );

    new ProblemDetailsFilter().catch(new PrebuiltProblem(problem), createHost(response));

    expect(setHeader).toHaveBeenCalledWith('Retry-After', '42');
    expect(status).toHaveBeenCalledWith(429);
  });
});
