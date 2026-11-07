import { StandardSchemaValidationPipe } from '@nestjs/common';
import type { StandardSchemaV1 } from '@standard-schema/spec';
import { ValidationError } from '../domain/errors.js';

function issuePath(issue: StandardSchemaV1.Issue): string {
  if (!issue.path?.length) return '(cuerpo)';
  return issue.path
    .map((segment) => String(typeof segment === 'object' ? segment.key : segment))
    .join('.');
}

/**
 * Validates `@Body({ schema })`, `@Param(..., { schema })` and `@Query({ schema })` with any
 * Standard Schema library (we use Zod) and answers 400 listing the failing fields.
 */
export function createValidationPipe(): StandardSchemaValidationPipe {
  return new StandardSchemaValidationPipe({
    exceptionFactory: (issues) =>
      new ValidationError(
        issues.map((issue) => ({ field: issuePath(issue), message: issue.message })),
      ),
  });
}
