import { z } from 'zod';
import { countsForRanking, type Endorsement } from '../domain/endorsement.js';
import type { ReviewProps } from '../domain/review.js';

export const reputationIdSchema = z.uuid().transform((id) => id.toLowerCase());
export const newReviewSchema = z.strictObject({
  id: z.uuid({ version: 'v7' }).transform((id) => id.toLowerCase()),
  servicioId: reputationIdSchema,
  calificacion: z.number().int().min(1).max(5),
  comentario: z.string().trim().max(2000).nullish(),
  fotos: z
    .array(reputationIdSchema)
    .max(3)
    .refine((ids) => new Set(ids).size === ids.length, 'Los archivos deben ser distintos.')
    .default([]),
});
export type NewReviewDto = z.infer<typeof newReviewSchema>;

export function toReviewDto(review: ReviewProps) {
  return {
    id: review.id,
    servicioId: review.serviceId,
    calificacion: review.rating,
    comentario: review.comment,
    fotos: review.photos.filter((photo) => !photo.hiddenAt).map((photo) => photo.fileId),
    estado: review.state,
    motivoEstado: review.stateReason,
    creadoEn: review.createdAt.toISOString(),
    actualizadoEn: review.updatedAt.toISOString(),
    publicadaEn: review.publishedAt?.toISOString() ?? null,
  };
}

export function toEndorsementDto(endorsement: Endorsement) {
  return {
    id: endorsement.id,
    servicioId: endorsement.serviceId,
    creadoEn: endorsement.createdAt.toISOString(),
    cuentaParaRanking: countsForRanking(endorsement),
  };
}
