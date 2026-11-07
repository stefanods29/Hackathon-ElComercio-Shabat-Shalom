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

/** Tables of the `identidad` schema. Only the Identity module queries them. */
export interface IdentityTables {
  'identidad.zonas': ZonesTable;
  'identidad.usuarios': UsersTable;
}
