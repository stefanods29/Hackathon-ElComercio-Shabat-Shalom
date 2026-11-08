export type ImageScreening = 'limpia' | 'dudosa' | 'sin_verificar';
export type ScreeningFlag =
  | 'texto_bloqueado'
  | 'imagen_dudosa'
  | 'imagen_sin_verificar'
  | 'patron_de_resenas'
  | 'autor_suspendido'
  | 'autor_no_verificado';

const BLOCKED_WORDS = new Set(['estupido', 'idiota', 'imbecil', 'mierda', 'puta']);

export function hasBlockedText(parts: readonly string[]): boolean {
  return parts.some((part) =>
    part
      .normalize('NFKD')
      .toLowerCase()
      .replace(/\p{M}/gu, '')
      .split(/[^\p{L}\p{N}]+/u)
      .some((word) => BLOCKED_WORDS.has(word)),
  );
}
