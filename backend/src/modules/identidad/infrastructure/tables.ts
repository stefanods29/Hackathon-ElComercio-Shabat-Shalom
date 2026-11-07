import type { NullableTimestamp, Timestamp, WithDefault } from '../../../shared/db/types.js';

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
  telefono: string;
  nombre_visible: string;
  zona_id: string | null;
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

/** Tables of the `identidad` schema. Only the Identity module queries them. */
export interface IdentityTables {
  'identidad.zonas': ZonesTable;
  'identidad.usuarios': UsersTable;
  'identidad.codigos_otp': OtpCodesTable;
  'identidad.limites_otp': OtpLimitsTable;
}
