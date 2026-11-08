import type { ConsentPurpose } from '../domain/consents.js';
import type { NullableTimestamp, Timestamp, WithDefault } from '../../../shared/db/types.js';
import type { SessionRevocationReason } from '../application/session-ports.js';

/** Table and column names follow the database schema (Spanish), as the architecture sets. */
export interface ZonesTable {
  id: WithDefault<string>;
  nombre: string;
  distrito: string;
  /** geography(MultiPolygon): written and queried with PostGIS SQL. */
  limite: unknown;
  creado_en: WithDefault<Date>;
  actualizado_en: WithDefault<Date>;
}

export interface UsersTable {
  id: WithDefault<string>;
  telefono: string | null;
  nombre_visible: string;
  zona_id: string | null;
  zona_elegida_en: NullableTimestamp;
  nivel_confianza: WithDefault<number>;
  roles: WithDefault<string[]>;
  creado_en: WithDefault<Date>;
  actualizado_en: Timestamp;
  eliminado_en: NullableTimestamp;
}

export interface OtpCodesTable {
  id: WithDefault<string>;
  telefono: string;
  codigo_hash: string;
  canal: 'sms' | 'whatsapp';
  ip: string | null;
  intentos: WithDefault<number>;
  expira_en: Timestamp;
  usado_en: NullableTimestamp;
  creado_en: WithDefault<Date>;
}

/** Private failure counters and blocks, independent of issued OTP codes. */
export interface OtpLimitsTable {
  ambito: 'telefono' | 'ip';
  identificador: string;
  intentos: number;
  ventana_desde: Timestamp;
  bloqueado_hasta: NullableTimestamp;
}

export interface SessionsTable {
  id: WithDefault<string>;
  usuario_id: string;
  familia_id: string;
  refresh_hash: string;
  dispositivo: string | null;
  creada_en: WithDefault<Date>;
  expira_en: Timestamp;
  rotada_en: NullableTimestamp;
  revocada_en: NullableTimestamp;
  motivo: SessionRevocationReason | null;
}

export interface ConsentsTable {
  id: WithDefault<string>;
  usuario_id: string;
  finalidad: ConsentPurpose;
  version: number;
  aceptado: boolean;
  decidido_en: Timestamp;
}

export interface PresencesTable {
  usuario_id: string;
  fecha: string;
  dentro_de_la_zona: boolean;
}

export interface EndorsementsTable {
  vecino_id: string;
  avalista_id: string;
  zona_id: string;
  creado_en: Timestamp;
}

export interface ConfirmationsTable {
  id: WithDefault<string>;
  vecino_id: string;
  moderador_id: string;
  zona_id: string;
  motivo: string;
  nivel: 1 | 2;
  creada_en: Timestamp;
}

/** Tables of the `identidad` schema. Only the Identity module queries them. */
export interface IdentityTables {
  'identidad.zonas': ZonesTable;
  'identidad.usuarios': UsersTable;
  'identidad.codigos_otp': OtpCodesTable;
  'identidad.limites_otp': OtpLimitsTable;
  'identidad.sesiones': SessionsTable;
  'identidad.consentimientos': ConsentsTable;
  'identidad.presencias': PresencesTable;
  'identidad.avales': EndorsementsTable;
  'identidad.confirmaciones': ConfirmationsTable;
}
