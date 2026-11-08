const ERROR_TYPES = new Set(['Error', 'TypeError', 'RangeError', 'SyntaxError', 'ReferenceError']);
export function errorCategory(error: unknown): string {
  if (error instanceof TypeError) return 'TypeError';
  if (error instanceof RangeError) return 'RangeError';
  if (error instanceof SyntaxError) return 'SyntaxError';
  return 'Error';
}
/** Rebuild from an allowlist: arbitrary SDK context, messages and credentials cannot pass. */
export function privateEvent(event: { exception?: { values?: { type?: string }[] } }) {
  const original = event.exception?.values?.[0]?.type;
  const category = original && ERROR_TYPES.has(original) ? original : 'Error';
  return {
    type: undefined,
    level: 'error' as const,
    message: 'Error técnico de Vecinal',
    tags: { component: 'backend' },
    exception: { values: [{ type: category, value: 'Detalle omitido por privacidad' }] },
  };
}
export function safeRoute(path: unknown): string {
  if (typeof path !== 'string' || !path.startsWith('/') || path.includes('?') || path.length > 120)
    return 'unmatched';
  if (/[0-9a-f]{8}-[0-9a-f-]{27,}/i.test(path) || !/^\/[a-zA-Z0-9_/:.{}-]*$/.test(path))
    return 'unmatched';
  return path;
}
