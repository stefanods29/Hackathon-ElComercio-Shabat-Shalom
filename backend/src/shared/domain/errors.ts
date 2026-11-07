/**
 * Errors that the domain and the use cases throw on purpose.
 * The API layer translates them to Problem Details (RFC 9457); the domain knows nothing about HTTP.
 * `code` values are part of the public contract (the phone branches on them) and stay in Spanish.
 */
export abstract class ApplicationError extends Error {
  abstract readonly code: string;

  constructor(
    message: string,
    readonly extensions: Readonly<Record<string, unknown>> = {},
  ) {
    super(message);
    this.name = new.target.name;
  }
}

export class ResourceNotFound extends ApplicationError {
  override readonly code = 'recurso_no_encontrado';

  constructor(resource: string, id: string) {
    super(`No encontramos ${resource} con id ${id}.`, { recurso: resource, id });
  }
}

export class RateLimitExceeded extends ApplicationError {
  constructor(
    override readonly code: string,
    message: string,
    readonly retryAfterSeconds: number,
  ) {
    super(message, { reintentarEnSegundos: retryAfterSeconds });
  }
}

export class AuthenticationFailure extends ApplicationError {
  constructor(
    override readonly code: string,
    message: string,
  ) {
    super(message);
  }
}

/** Another neighbor changed the resource first: the version seen on the phone is stale. */
export class VersionConflict extends ApplicationError {
  override readonly code = 'conflicto_de_version';

  constructor(
    readonly expectedVersion: number,
    readonly currentVersion: number,
  ) {
    super('Alguien actualizó esto antes que tú. Revisa la información más reciente.', {
      versionEsperada: expectedVersion,
      versionActual: currentVersion,
    });
  }
}

/**
 * Kind of violated rule, so the API picks the HTTP status:
 * - `conflict`: the current state prevents it (409), e.g. the favor was already taken.
 * - `forbidden`: the actor cannot do it (403), e.g. insufficient trust level.
 * - `invalid`: the data breaks the rule (422).
 */
export type RuleKind = 'conflict' | 'forbidden' | 'invalid';

export class BusinessRuleViolation extends ApplicationError {
  constructor(
    override readonly code: string,
    message: string,
    readonly kind: RuleKind = 'invalid',
    extensions: Readonly<Record<string, unknown>> = {},
  ) {
    super(message, extensions);
  }
}

export interface FieldError {
  /** Serialized as `campo` in the public contract. */
  readonly field: string;
  /** Serialized as `mensaje` in the public contract. */
  readonly message: string;
}

export class ValidationError extends ApplicationError {
  override readonly code = 'validacion';

  constructor(readonly errors: readonly FieldError[]) {
    super('La solicitud tiene datos inválidos.', {
      errores: errors.map((error) => ({ campo: error.field, mensaje: error.message })),
    });
  }
}
