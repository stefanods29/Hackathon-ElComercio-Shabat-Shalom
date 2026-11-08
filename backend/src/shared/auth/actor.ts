import type { Request } from 'express';

/** Role values are part of the contract (JWT claims and database) and stay in Spanish. */
export const ROLES = [
  'proveedor',
  'moderador',
  'coordinador',
  'brigadista',
  'curador',
  'administrador',
] as const;
export type Role = (typeof ROLES)[number];

/** Identity certified by the access token (claims `sub`, `zona`, `nivel`, `roles`). */
export interface Actor {
  readonly id: string;
  readonly zoneId: string | null;
  /** Trust level 0–3 (section 5.5). */
  readonly trustLevel: number;
  readonly roles: readonly Role[];
  /** Refresh-token family (`sid`); absent on development or legacy tokens. */
  readonly sessionId?: string;
}

export type AuthenticatedRequest = Request & { actor?: Actor };
