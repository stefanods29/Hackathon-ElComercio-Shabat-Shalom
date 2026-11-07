import { HttpException } from '@nestjs/common';
import {
  ApplicationError,
  AuthenticationFailure,
  BusinessRuleViolation,
  RateLimitExceeded,
  ResourceNotFound,
  ValidationError,
  VersionConflict,
} from '../domain/errors.js';

export const PROBLEM_CONTENT_TYPE = 'application/problem+json';

/**
 * Standard error response (RFC 9457). The `codigo` member is a stable code (public contract,
 * in Spanish) that the phone uses to decide what to show.
 */
export interface ProblemDetails {
  type: string;
  title: string;
  status: number;
  detail?: string;
  instance?: string;
  codigo: string;
  [extension: string]: unknown;
}

const TITLES: Readonly<Record<number, string>> = {
  400: 'Solicitud inválida',
  401: 'No autenticado',
  403: 'Acción no permitida',
  404: 'No encontrado',
  405: 'Método no permitido',
  409: 'Conflicto',
  413: 'Contenido demasiado grande',
  415: 'Tipo de contenido no soportado',
  422: 'No se pudo procesar',
  429: 'Demasiadas solicitudes',
  500: 'Error interno',
  503: 'Servicio no disponible',
};

const CODES_BY_STATUS: Readonly<Record<number, string>> = {
  400: 'solicitud_invalida',
  401: 'no_autenticado',
  403: 'prohibido',
  404: 'recurso_no_encontrado',
  405: 'metodo_no_permitido',
  409: 'conflicto',
  413: 'contenido_demasiado_grande',
  415: 'tipo_de_contenido_no_soportado',
  422: 'no_procesable',
  429: 'demasiadas_solicitudes',
  503: 'servicio_no_disponible',
};

/** Types are URI references relative to the API (RFC 9457 §3.1.1). */
export function problemType(code: string): string {
  return `/problemas/${code.replaceAll('_', '-')}`;
}

export function buildProblem(
  status: number,
  code: string,
  detail: string | undefined,
  instance?: string,
  extensions: Readonly<Record<string, unknown>> = {},
): ProblemDetails {
  return {
    ...extensions,
    type: problemType(code),
    title: TITLES[status] ?? 'Error',
    status,
    ...(detail ? { detail } : {}),
    ...(instance ? { instance } : {}),
    codigo: code,
  };
}

function statusForRule(error: BusinessRuleViolation): number {
  switch (error.kind) {
    case 'conflict':
      return 409;
    case 'forbidden':
      return 403;
    case 'invalid':
      return 422;
  }
}

function messageOf(error: HttpException): string | undefined {
  const response = error.getResponse();
  if (typeof response === 'string') return response;
  if (response && typeof response === 'object' && 'message' in response) {
    const message = (response as { message: unknown }).message;
    if (typeof message === 'string') return message;
    if (Array.isArray(message)) return message.map(String).join('; ');
  }
  return error.message;
}

/** Translates any error to Problem Details. Unknown errors never leak internal details. */
export function toProblemDetails(error: unknown, instance?: string): ProblemDetails {
  if (error instanceof ValidationError) {
    return buildProblem(400, error.code, error.message, instance, error.extensions);
  }
  if (error instanceof AuthenticationFailure) {
    return buildProblem(401, error.code, error.message, instance, error.extensions);
  }
  if (error instanceof ResourceNotFound) {
    return buildProblem(404, error.code, error.message, instance, error.extensions);
  }
  if (error instanceof RateLimitExceeded) {
    return buildProblem(429, error.code, error.message, instance, error.extensions);
  }
  if (error instanceof VersionConflict) {
    return buildProblem(409, error.code, error.message, instance, error.extensions);
  }
  if (error instanceof BusinessRuleViolation) {
    return buildProblem(
      statusForRule(error),
      error.code,
      error.message,
      instance,
      error.extensions,
    );
  }
  if (error instanceof ApplicationError) {
    return buildProblem(422, error.code, error.message, instance, error.extensions);
  }
  if (error instanceof HttpException) {
    const status = error.getStatus();
    const code = CODES_BY_STATUS[status] ?? (status >= 500 ? 'error_interno' : 'error_http');
    const detail = status >= 500 ? undefined : messageOf(error);
    return buildProblem(status, code, detail, instance);
  }
  return buildProblem(
    500,
    'error_interno',
    'Ocurrió un error inesperado. Intenta de nuevo en unos minutos.',
    instance,
  );
}

/**
 * Definitive rejection: retrying the same submission will not change the answer.
 * The phone moves it to "acciones por revisar"; every other error is retried with backoff.
 */
export function isDefinitiveRejection(status: number): boolean {
  return status >= 400 && status < 500 && status !== 408 && status !== 429;
}

/** Re-throws an already built problem (e.g. the stored response of a retried request). */
export class PrebuiltProblem extends Error {
  constructor(readonly problem: ProblemDetails) {
    super(problem.detail ?? problem.title);
    this.name = 'PrebuiltProblem';
  }
}
