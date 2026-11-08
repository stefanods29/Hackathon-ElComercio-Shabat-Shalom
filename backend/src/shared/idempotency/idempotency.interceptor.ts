import { createHash } from 'node:crypto';
import {
  type CallHandler,
  type ExecutionContext,
  Inject,
  Injectable,
  type NestInterceptor,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import type { Response } from 'express';
import { type Observable, catchError, from, mergeMap, of, throwError } from 'rxjs';
import {
  PrebuiltProblem,
  type ProblemDetails,
  isDefinitiveRejection,
  toProblemDetails,
} from '../api/problem-details.js';
import { IDEMPOTENCY_KEY_HEADER, IDEMPOTENT_REPLAYED_HEADER } from '../api/routes.js';
import type { AuthenticatedRequest } from '../auth/actor.js';
import { CLOCK, type Clock } from '../domain/clock.js';
import { BusinessRuleViolation, ValidationError } from '../domain/errors.js';
import {
  IDEMPOTENCY_STORE,
  type IdempotencyStore,
  type IdempotentRequest,
} from './idempotency-store.js';
import { IDEMPOTENT_METADATA, type IdempotencyPolicy } from './idempotent.decorator.js';
import { IdempotencyCounters } from '../observability/idempotency-counters.js';

/** Visible ASCII characters; a UUIDv7 generated on the phone is recommended. */
const KEY_FORMAT = /^[\x21-\x7E]{8,255}$/;

export function computeFingerprint(method: string, path: string, body: unknown): string {
  return createHash('sha256')
    .update(`${method.toUpperCase()} ${path}\n${JSON.stringify(body ?? null)}`)
    .digest('hex');
}

/**
 * `Idempotency-Key` semantics (aligned with the IETF draft and section 3.4):
 * - first time → runs the action and stores the response (2xx or a definitive 4xx rejection);
 * - retry with the same content → returns the stored response, with 200 if it succeeded
 *   (and the `Idempotent-Replayed: true` header), or the same rejection;
 * - same key with other content → 422; the same action still running → 409.
 * 5xx/408/429 errors release the key so the retry runs again.
 */
@Injectable()
export class IdempotencyInterceptor implements NestInterceptor {
  constructor(
    private readonly reflector: Reflector,
    @Inject(IDEMPOTENCY_STORE) private readonly store: IdempotencyStore,
    @Inject(CLOCK) private readonly clock: Clock,
    private readonly counters: IdempotencyCounters,
  ) {}

  async intercept(context: ExecutionContext, next: CallHandler): Promise<Observable<unknown>> {
    const policy = this.reflector.getAllAndOverride<IdempotencyPolicy | undefined>(
      IDEMPOTENT_METADATA,
      [context.getHandler(), context.getClass()],
    );
    if (!policy || context.getType() !== 'http') {
      return next.handle();
    }

    const http = context.switchToHttp();
    const request = http.getRequest<AuthenticatedRequest>();
    const response = http.getResponse<Response>();
    const key = request.header(IDEMPOTENCY_KEY_HEADER);

    if (!key || !KEY_FORMAT.test(key)) {
      throw new ValidationError([
        {
          field: 'Idempotency-Key',
          message: key
            ? 'Debe tener entre 8 y 255 caracteres ASCII visibles (se recomienda un UUIDv7).'
            : 'Toda escritura debe enviar la cabecera Idempotency-Key.',
        },
      ]);
    }

    const fingerprintBody =
      policy === 'session-bound' ? [request.actor?.sessionId ?? null, request.body] : request.body;
    const idempotentRequest: IdempotentRequest = {
      scope: request.actor?.id ?? 'anonimo',
      key,
      method: request.method,
      path: request.originalUrl,
      fingerprint: computeFingerprint(request.method, request.originalUrl, fingerprintBody),
    };

    const reservation = await this.store.reserve(idempotentRequest, this.clock.now());
    this.counters.record(reservation.kind);
    switch (reservation.kind) {
      case 'replay':
        response.setHeader(IDEMPOTENT_REPLAYED_HEADER, 'true');
        if (reservation.httpStatus >= 400) {
          throw new PrebuiltProblem(reservation.body as ProblemDetails);
        }
        response.status(200);
        return of(reservation.body);
      case 'in_progress':
        response.setHeader('retry-after', '2');
        throw new BusinessRuleViolation(
          'solicitud_en_curso',
          'Ya estamos procesando esta misma acción. Reintenta en unos segundos.',
          'conflict',
        );
      case 'fingerprint_mismatch':
        throw new BusinessRuleViolation(
          'idempotency_key_reutilizada',
          'Esta Idempotency-Key ya se usó con otro contenido. Genera una clave nueva por acción.',
          'invalid',
        );
      case 'new':
        break;
    }

    return next.handle().pipe(
      mergeMap(async (body: unknown) => {
        await this.store.complete(idempotentRequest.scope, key, response.statusCode, body ?? null);
        return body;
      }),
      catchError((error: unknown) =>
        from(this.recordFailure(idempotentRequest, error, request.originalUrl)).pipe(
          mergeMap(() => throwError(() => error)),
        ),
      ),
    );
  }

  private async recordFailure(
    idempotentRequest: IdempotentRequest,
    error: unknown,
    instance: string,
  ): Promise<void> {
    const problem = toProblemDetails(error, instance);
    if (isDefinitiveRejection(problem.status)) {
      await this.store.complete(
        idempotentRequest.scope,
        idempotentRequest.key,
        problem.status,
        problem,
      );
    } else {
      await this.store.release(idempotentRequest.scope, idempotentRequest.key);
    }
  }
}
