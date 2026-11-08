import { z } from 'zod';

/**
 * Field-by-field copy of `contracts/directorio-emergencia.schema.json` (Phase 1). The contract
 * test against the JSON Schema itself still runs in `infra/cdn` (`npm test`).
 */
const entryId = z.string().regex(/^[a-z0-9-]{2,60}$/);
const fileName = z.string().regex(/^[a-z0-9-]{2,60}\.json$/);
const httpsUrl = z
  .string()
  .max(2048)
  .refine((value) => {
    try {
      return new URL(value).protocol === 'https:';
    } catch {
      return false;
    }
  }, 'Debe ser una dirección https.');

const entryShape = z.strictObject({
  id: entryId,
  tipo: z.enum(['numero', 'punto_de_encuentro', 'centro_de_salud', 'albergue']),
  nombre: z.string().min(2).max(120),
  telefono: z
    .string()
    .regex(/^\+?[0-9][0-9 ]{1,18}[0-9]$/)
    .optional(),
  ubicacion: z
    .strictObject({
      lat: z.number().min(-90).max(90),
      lng: z.number().min(-180).max(180),
    })
    .optional(),
  direccion: z.string().min(2).max(200).optional(),
  descripcion: z.string().min(2).max(300).optional(),
  fuente: z.strictObject({
    nombre: z.string().min(2).max(120),
    url: httpsUrl.optional(),
  }),
  verificadoEn: z.iso.date(),
});

/** The schema's `if/then/else`: a number needs its phone; a place needs its location. */
export const entrySchema = entryShape.superRefine((entry, context) => {
  if (entry.tipo === 'numero' && !entry.telefono) {
    context.addIssue({
      code: 'custom',
      path: ['telefono'],
      message: 'Un número de emergencia necesita su teléfono.',
    });
  }
  if (entry.tipo !== 'numero' && !entry.ubicacion) {
    context.addIssue({
      code: 'custom',
      path: ['ubicacion'],
      message: 'Un lugar necesita su ubicación.',
    });
  }
});

export const publicationSchema = z.strictObject({
  versionVista: z.int().min(1),
  distrito: z.string().min(2).max(80),
  entradas: z.array(entrySchema).min(1).max(500),
});

export const directorySchema = z.strictObject({
  version: z.int().min(1),
  distrito: z.string().min(2).max(80),
  generadoEn: z.iso.datetime({ offset: true }),
  entradas: z.array(entrySchema).min(1).max(500),
});

export const indexSchema = z.strictObject({
  version: z.int().min(1),
  generadoEn: z.iso.datetime({ offset: true }),
  distritos: z
    .array(
      z.strictObject({
        id: entryId,
        archivo: fileName,
        version: z.int().min(1),
        sha256: z.string().regex(/^[0-9a-f]{64}$/),
        bytes: z.int().min(1).max(1_048_576),
        zonas: z.array(z.uuid()).min(1),
      }),
    )
    .min(1),
});

export const fileNameSchema = fileName;
