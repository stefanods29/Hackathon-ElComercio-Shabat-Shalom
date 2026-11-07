import { ValidationError } from '../../../shared/domain/errors.js';
import { isUuidV7 } from '../../../shared/domain/ids.js';
import type { NearbyCursor } from './ports.js';

export function invalidNearbyCursor(): ValidationError {
  return new ValidationError([
    {
      field: 'cursor',
      message: 'El cursor no es válido para esta búsqueda. Inicia la búsqueda de nuevo.',
    },
  ]);
}

export function decodeNearbyCursor(value: string): NearbyCursor {
  try {
    if (value.length > 512 || !/^[A-Za-z0-9_-]+$/.test(value)) throw invalidNearbyCursor();
    const buffer = Buffer.from(value, 'base64url');
    if (buffer.toString('base64url') !== value) throw invalidNearbyCursor();
    const parsed: unknown = JSON.parse(buffer.toString('utf8'));
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) throw invalidNearbyCursor();
    const fields = parsed as Record<string, unknown>;
    if (
      Object.keys(fields).length !== 2 ||
      typeof fields.d !== 'number' ||
      !Number.isFinite(fields.d) ||
      fields.d < 0 ||
      fields.d > 5_000 ||
      fields.d % 50 !== 0 ||
      typeof fields.id !== 'string' ||
      !isUuidV7(fields.id)
    )
      throw invalidNearbyCursor();
    return { d: fields.d, id: fields.id };
  } catch {
    throw invalidNearbyCursor();
  }
}

export function encodeNearbyCursor(cursor: NearbyCursor): string {
  return Buffer.from(JSON.stringify(cursor)).toString('base64url');
}
