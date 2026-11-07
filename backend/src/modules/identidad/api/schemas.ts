import { z } from 'zod';
import type { IssuedSession } from '../application/issue-credentials.js';
import type { IssuedRefreshSession } from '../application/create-session.js';

const phoneSchema = z
  .string()
  .regex(/^\+[1-9][0-9]{7,14}$/, 'usa el formato internacional, p. ej., +51987654321');

export const requestOtpSchema = z.object({
  telefono: phoneSchema,
  canal: z.enum(['sms', 'whatsapp']).default('sms'),
});
export type RequestOtpDto = z.infer<typeof requestOtpSchema>;

export const verifyOtpSchema = z.object({
  telefono: phoneSchema,
  codigo: z.string().regex(/^[0-9]{6}$/, 'debe tener exactamente 6 dígitos'),
  dispositivo: z.string().max(80).optional(),
});
export type VerifyOtpDto = z.infer<typeof verifyOtpSchema>;

export const firebaseSignInSchema = z.object({
  tokenFirebase: z.string().min(1).max(4096),
  dispositivo: z.string().max(80).optional(),
});
export type FirebaseSignInDto = z.infer<typeof firebaseSignInSchema>;

export const refreshSessionSchema = z.object({
  refreshToken: z.string().min(1).max(512),
});
export type RefreshSessionDto = z.infer<typeof refreshSessionSchema>;

export const chooseZoneSchema = z.object({
  zonaId: z.uuid({ message: 'debe ser el UUID de una zona' }),
});
export type ChooseZoneDto = z.infer<typeof chooseZoneSchema>;

export interface SessionResponse {
  tokenDeAcceso: string;
  expiraEn: string;
  usuario: {
    id: string;
    nombreVisible: string;
    zonaId: string | null;
    nivel: number;
    roles: readonly string[];
  };
}

export interface RenewableSessionResponse extends SessionResponse {
  refreshToken: string;
  refreshExpiraEn: string;
}

export function toRenewableSessionResponse(
  session: IssuedRefreshSession,
): RenewableSessionResponse {
  return {
    ...toSessionResponse(session),
    refreshToken: session.refreshToken,
    refreshExpiraEn: session.refreshExpiresAt.toISOString(),
  };
}

export function toSessionResponse(session: IssuedSession): SessionResponse {
  return {
    tokenDeAcceso: session.accessToken,
    expiraEn: session.expiresAt.toISOString(),
    usuario: {
      id: session.user.id,
      nombreVisible: session.user.displayName,
      zonaId: session.user.zoneId,
      nivel: session.user.trustLevel,
      roles: session.user.roles,
    },
  };
}
