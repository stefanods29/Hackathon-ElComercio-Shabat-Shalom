import { z } from 'zod';
import {
  NEEDS,
  OPERATIONAL_ROLES,
  PRIORITIES,
  REQUEST_STATES,
  RESOURCE_TYPES,
  type Assignment,
  type CriticalResource,
  type DutyShift,
  type EmergencyEvent,
  type HelpRequest,
  type OperationalGrant,
  type SupportGroup,
} from '../domain/emergency.js';

const id = z.uuid();
const time = z.iso.datetime({ offset: true }).transform((value) => new Date(value));
const version = z.int().min(1);
const reason = z.string().trim().min(1).max(500);
export const idParams = z.strictObject({ id });
export const zoneParams = z.strictObject({ zonaId: id });
export const pageQuery = z.strictObject({
  cursor: id.optional(),
  limite: z.coerce.number().int().min(1).max(100).default(50),
});
export const auditQuery = z.strictObject({
  cursor: z
    .string()
    .regex(/^[0-9]{1,19}$/)
    .optional(),
  limite: z.coerce.number().int().min(1).max(100).default(50),
});
export const coordinates = z.strictObject({
  lat: z.number().finite().min(-90).max(90),
  lng: z.number().finite().min(-180).max(180),
});
export const newEvent = z.strictObject({ id, nivel: z.int().min(1).max(3) });
export const closeEvent = z.strictObject({ versionVista: version, motivo: reason });
export const newRequest = z.strictObject({
  id,
  eventoId: id,
  necesidad: z.enum(NEEDS),
  prioridad: z.enum(PRIORITIES).default('media'),
  descripcion: z.string().trim().min(1).max(2000),
  ubicacion: coordinates,
  riesgoVital: z.boolean().default(false),
});
export const changeState = z.strictObject({
  versionVista: version,
  estado: z.enum(REQUEST_STATES),
  motivo: reason.optional(),
});
export const assignRequest = z.strictObject({
  versionVista: version,
  usuarioId: id,
  rol: z.enum(['coordinador', 'brigadista']).default('brigadista'),
});
export const grantOperator = z.strictObject({
  id,
  usuarioId: id,
  zonaId: id,
  rol: z.enum(OPERATIONAL_ROLES),
  dniRevisadoEn: time,
  capacitacionEn: time,
  confidencialidadEn: time,
  referenciaRevision: z.string().trim().min(1).max(120),
  venceEn: time,
  versionVista: version.optional(),
});
export const revokeOperator = z.strictObject({ versionVista: version, motivo: reason });
export const newShift = z.strictObject({
  id,
  usuarioId: id,
  rol: z.enum(OPERATIONAL_ROLES),
  inicio: time,
  fin: time,
});
export const seenVersion = z.strictObject({ versionVista: version });
export const syncAccess = z.strictObject({ alcance: z.enum(['resumen', 'exacta']) });
export type SyncAccessDto = z.infer<typeof syncAccess>;
export const prioritizeRequest = z.strictObject({
  versionVista: version,
  prioridad: z.enum(PRIORITIES),
  motivo: reason,
});
export type PrioritizeRequestDto = z.infer<typeof prioritizeRequest>;
export const newGroup = z.strictObject({
  id,
  nombre: z.string().trim().min(2).max(100),
  miembros: z.array(id).max(100),
});
export const groupMembers = z.strictObject({
  versionVista: version,
  miembros: z.array(id).max(100),
});
export const supportZones = z.strictObject({ zonas: z.array(id).max(10) });
export const newResource = z.strictObject({
  id,
  tipo: z.enum(RESOURCE_TYPES),
  cantidad: z.int().min(0).max(1000000),
  ubicacion: coordinates,
});
export const updateResource = z.strictObject({
  versionVista: version,
  cantidad: z.int().min(0).max(1000000),
});
export const verifyResource = z.strictObject({
  versionVista: version,
  etiqueta: z.string().trim().min(1).max(160),
  fuenteUrl: z
    .url()
    .max(500)
    .refine((value) => {
      try {
        const url = new URL(value);
        return url.protocol === 'https:' && !url.username && !url.password && !url.hash;
      } catch {
        return false;
      }
    }, 'La fuente debe usar HTTPS sin credenciales.')
    .optional(),
  oficial: z.boolean().default(false),
});

export type IdParams = z.infer<typeof idParams>;
export type ZoneParams = z.infer<typeof zoneParams>;
export type PageQuery = z.infer<typeof pageQuery>;
export type AuditQuery = z.infer<typeof auditQuery>;
export type NewEventDto = z.infer<typeof newEvent>;
export type CloseEventDto = z.infer<typeof closeEvent>;
export type NewRequestDto = z.infer<typeof newRequest>;
export type ChangeStateDto = z.infer<typeof changeState>;
export type AssignRequestDto = z.infer<typeof assignRequest>;
export type GrantOperatorDto = z.infer<typeof grantOperator>;
export type RevokeOperatorDto = z.infer<typeof revokeOperator>;
export type NewShiftDto = z.infer<typeof newShift>;
export type VersionDto = z.infer<typeof seenVersion>;
export type NewGroupDto = z.infer<typeof newGroup>;
export type GroupMembersDto = z.infer<typeof groupMembers>;
export type SupportZonesDto = z.infer<typeof supportZones>;
export type NewResourceDto = z.infer<typeof newResource>;
export type UpdateResourceDto = z.infer<typeof updateResource>;
export type VerifyResourceDto = z.infer<typeof verifyResource>;

export function toEventDto(event: EmergencyEvent) {
  return {
    id: event.id,
    zonaId: event.zoneId,
    nivel: event.level,
    estado: event.state,
    version: event.version,
    activadoEn: event.createdAt.toISOString(),
    cerradoEn: event.closedAt?.toISOString() ?? null,
    fuente: event.source,
  };
}
export function toRequestDto(request: HelpRequest, assignments?: readonly Assignment[]) {
  return {
    id: request.id,
    eventoId: request.eventId,
    zonaId: request.zoneId,
    necesidad: request.need,
    prioridad: request.priority,
    estado: request.state,
    version: request.version,
    celda: request.cell,
    creadoEn: request.createdAt.toISOString(),
    venceEn: request.expiresAt.toISOString(),
    vistoEn: request.seenAt?.toISOString() ?? null,
    escalarEn: request.escalateAt?.toISOString() ?? null,
    ...(assignments
      ? {
          asignaciones: assignments.map((item) => ({
            usuarioId: item.userId,
            rol: item.role,
            venceEn: item.expiresAt.toISOString(),
          })),
        }
      : {}),
  };
}
export function toGrantDto(grant: OperationalGrant) {
  return {
    id: grant.id,
    usuarioId: grant.userId,
    zonaId: grant.zoneId,
    rol: grant.role,
    version: grant.version,
    venceEn: grant.expiresAt.toISOString(),
    revocadaEn: grant.revokedAt?.toISOString() ?? null,
  };
}
export function toShiftDto(shift: DutyShift) {
  return {
    id: shift.id,
    usuarioId: shift.userId,
    zonaId: shift.zoneId,
    rol: shift.role,
    inicio: shift.startsAt.toISOString(),
    fin: shift.endsAt.toISOString(),
    finalizadoEn: shift.endedAt?.toISOString() ?? null,
    version: shift.version,
  };
}
export function toGroupDto(group: SupportGroup) {
  return {
    id: group.id,
    zonaId: group.zoneId,
    nombre: group.name,
    miembros: group.members,
    version: group.version,
    verificadoEn: group.verifiedAt.toISOString(),
  };
}
export function toResourceDto(resource: CriticalResource, now: Date) {
  return {
    id: resource.id,
    zonaId: resource.zoneId,
    tipo: resource.type,
    cantidad: resource.quantity,
    celda: resource.cell,
    reportadoEn: resource.reportedAt.toISOString(),
    umbralAntiguedadSegundos: resource.staleAfterSeconds,
    posiblementeDesactualizado:
      now.getTime() - resource.reportedAt.getTime() >= resource.staleAfterSeconds * 1000,
    verificacion: resource.verification,
    confirmaciones: resource.confirmations,
    descripcion: resource.publicLabel ?? `Recurso: ${resource.type}`,
    fuenteUrl: resource.sourceUrl,
    oficial: resource.official,
    version: resource.version,
  };
}
export function page<T extends { id: string }>(items: readonly T[], limit: number) {
  const elements = items.slice(0, limit);
  return {
    elementos: elements,
    siguienteCursor: items.length > limit ? elements.at(-1)!.id : null,
  };
}
