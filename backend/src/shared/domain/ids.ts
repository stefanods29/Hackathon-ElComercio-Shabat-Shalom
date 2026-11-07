import { v7 as uuidv7, validate, version } from 'uuid';

/** UUIDv7 ids: time-ordered and generated on the phone without coordination. */
export function newId(): string {
  return uuidv7();
}

export function isUuidV7(value: string): boolean {
  return validate(value) && version(value) === 7;
}
