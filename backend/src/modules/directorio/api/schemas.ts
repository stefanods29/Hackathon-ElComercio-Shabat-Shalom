import { z } from 'zod';
import type { Category } from '../application/ports.js';
import type { ProviderProps } from '../domain/provider-profile.js';
import { attributesFit, type ServiceProps } from '../domain/service.js';

export const directoryIdSchema = z.uuid();
export const providerSchema = z.strictObject({
  nombrePublico: z.string().trim().min(2).max(60),
  descripcion: z.string().trim().max(500).nullish(),
});
export type ProviderDto = z.infer<typeof providerSchema>;

const serviceFields = {
  categoriaId: z.string().regex(/^[a-z0-9-]{2,40}$/),
  titulo: z.string().trim().min(3).max(120),
  descripcion: z.string().trim().max(2000).nullish(),
  ubicacion: z.strictObject({
    lat: z.number().min(-90).max(90),
    lng: z.number().min(-180).max(180),
  }),
  muestraUbicacionExacta: z.boolean().default(false),
  radioCoberturaM: z.number().int().min(100).max(20000).default(2000),
  disponibleEnEmergencia: z.boolean().default(false),
  atributos: z
    .record(z.string(), z.json())
    .refine(attributesFit, 'Los atributos no pueden superar 4096 bytes en UTF-8.')
    .default({}),
};
export const newServiceSchema = z.strictObject({
  ...serviceFields,
  id: z.uuid({ version: 'v7' }),
});
export const editServiceSchema = z.strictObject({
  ...serviceFields,
  versionVista: z.number().int().min(1),
});
export type NewServiceDto = z.infer<typeof newServiceSchema>;
export type EditServiceDto = z.infer<typeof editServiceSchema>;

export function toServiceData(body: NewServiceDto | EditServiceDto) {
  return {
    categoryId: body.categoriaId,
    title: body.titulo,
    description: body.descripcion ?? null,
    location: body.ubicacion,
    showExactLocation: body.muestraUbicacionExacta,
    coverageRadiusMeters: body.radioCoberturaM,
    availableInEmergency: body.disponibleEnEmergencia,
    attributes: body.atributos,
  };
}

export function toCategoryDto(category: Category) {
  return {
    id: category.id,
    nombre: category.name,
    icono: category.icon,
    utilEnEmergencia: category.usefulInEmergency,
    orden: category.order,
  };
}

export function toProviderDto(provider: ProviderProps) {
  return {
    id: provider.id,
    nombrePublico: provider.publicName,
    descripcion: provider.description,
    actualizadoEn: provider.updatedAt.toISOString(),
  };
}

export function toServiceDto(service: ServiceProps) {
  return {
    id: service.id,
    proveedorId: service.providerId,
    zonaId: service.zoneId,
    categoriaId: service.categoryId,
    titulo: service.title,
    descripcion: service.description,
    ubicacion: { ...service.publicLocation },
    radioCoberturaM: service.coverageRadiusMeters,
    disponibleEnEmergencia: service.availableInEmergency,
    atributos: service.attributes,
    totalResenas: service.reviewCount,
    promedio: service.average,
    puntajeRanking: service.rankingScore,
    vistosBuenosDeLaZona: service.zoneEndorsementCount,
    version: service.version,
    creadoEn: service.createdAt.toISOString(),
    actualizadoEn: service.updatedAt.toISOString(),
    eliminadoEn: service.deletedAt?.toISOString() ?? null,
  };
}
