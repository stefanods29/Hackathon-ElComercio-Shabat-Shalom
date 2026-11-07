import { z } from 'zod';
import { POST_TYPES, type PostProps } from '../domain/post.js';

/** Contract: `contracts/openapi.yaml` → `NuevaPublicacion`. JSON keys stay in Spanish. */
export const newPostSchema = z.object({
  id: z.uuid({ version: 'v7', message: 'debe ser un UUIDv7 generado en el celular' }),
  tipo: z.enum(POST_TYPES),
  categoria: z.string().trim().min(2).max(40),
  titulo: z.string().trim().min(3).max(120),
  descripcion: z.string().trim().max(2000).nullish(),
  ubicacion: z
    .object({ lat: z.number().min(-90).max(90), lng: z.number().min(-180).max(180) })
    .nullish(),
  venceEn: z.iso.datetime({ offset: true }).nullish(),
});
export type NewPostDto = z.infer<typeof newPostSchema>;

/** Contract: `contracts/openapi.yaml` → `TomarFavor`. */
export const takeFavorSchema = z.object({
  versionVista: z.number().int().min(1),
});
export type TakeFavorDto = z.infer<typeof takeFavorSchema>;

export const postIdSchema = z.uuid({ message: 'id de publicación inválido' });

/** Contract: `contracts/openapi.yaml` → `Publicacion`. */
export interface PostDto {
  id: string;
  autorId: string;
  zonaId: string;
  tipo: string;
  categoria: string;
  titulo: string;
  descripcion: string | null;
  ubicacion: { lat: number; lng: number } | null;
  estado: string;
  tomadaPorId: string | null;
  version: number;
  venceEn: string | null;
  creadoEn: string;
  actualizadoEn: string;
}

export function toPostDto(post: PostProps): PostDto {
  return {
    id: post.id,
    autorId: post.authorId,
    zonaId: post.zoneId,
    tipo: post.type,
    categoria: post.category,
    titulo: post.title,
    descripcion: post.description,
    ubicacion: post.location ? { lat: post.location.lat, lng: post.location.lng } : null,
    estado: post.status,
    tomadaPorId: post.takenById,
    version: post.version,
    venceEn: post.expiresAt ? post.expiresAt.toISOString() : null,
    creadoEn: post.createdAt.toISOString(),
    actualizadoEn: post.updatedAt.toISOString(),
  };
}
