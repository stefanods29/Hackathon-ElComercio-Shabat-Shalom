import { z } from 'zod';
import { CONSENT_PURPOSES } from '../domain/consents.js';

export const residenceIdSchema = z.uuid();

export const presenceSchema = z.strictObject({ fecha: z.iso.date(), dentroDeLaZona: z.boolean() });
export type PresenceDto = z.infer<typeof presenceSchema>;

export const confirmationSchema = z.strictObject({
  motivo: z.string().trim().min(1).max(500),
  nivel: z.union([z.literal(1), z.literal(2)]).default(1),
});
export type ConfirmationDto = z.infer<typeof confirmationSchema>;

export const consentSchema = z.strictObject({
  finalidad: z.enum(CONSENT_PURPOSES),
  version: z.number().int().min(1).max(2147483647),
  aceptado: z.boolean(),
});
export type ConsentDto = z.infer<typeof consentSchema>;

export const rectificationSchema = z.strictObject({
  nombreVisible: z.string().trim().min(2).max(60),
});
export type RectificationDto = z.infer<typeof rectificationSchema>;
