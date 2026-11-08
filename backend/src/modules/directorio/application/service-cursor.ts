import { ValidationError } from '../../../shared/domain/errors.js';
import { isUuidV7 } from '../../../shared/domain/ids.js';
import type { ServiceCursor } from './search-ports.js';

export function invalidServiceCursor(): ValidationError {
  return new ValidationError([
    { field: 'cursor', message: 'El cursor no es válido. Inicia la búsqueda de nuevo.' },
  ]);
}

export function decodeServiceCursor(value: string): ServiceCursor {
  try {
    if (value.length > 512 || !/^[A-Za-z0-9_-]+$/.test(value)) throw invalidServiceCursor();
    const bytes = Buffer.from(value, 'base64url');
    if (bytes.toString('base64url') !== value) throw invalidServiceCursor();
    const parsed: unknown = JSON.parse(bytes.toString('utf8'));
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed))
      throw invalidServiceCursor();
    const fields = parsed as Record<string, unknown>;
    if (
      Object.keys(fields).length !== 3 ||
      typeof fields.v !== 'number' ||
      !Number.isInteger(fields.v) ||
      fields.v < 0 ||
      fields.v > 2147483647 ||
      typeof fields.p !== 'number' ||
      !Number.isFinite(fields.p) ||
      fields.p < 0 ||
      fields.p > 5 ||
      Number(fields.p.toFixed(4)) !== fields.p ||
      typeof fields.id !== 'string' ||
      !isUuidV7(fields.id)
    )
      throw invalidServiceCursor();
    return { v: fields.v, p: fields.p, id: fields.id };
  } catch {
    throw invalidServiceCursor();
  }
}

export function encodeServiceCursor(cursor: ServiceCursor): string {
  return Buffer.from(JSON.stringify(cursor)).toString('base64url');
}
