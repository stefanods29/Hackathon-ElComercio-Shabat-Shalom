import type { Jsonb, NullableTimestamp, Timestamp, WithDefault } from './types.js';

// Table and column names come from the approved architecture (Spanish); code names are English.
export interface IdempotencyTable {
  alcance: string;
  clave: string;
  metodo: string;
  ruta: string;
  huella: string;
  estado: 'en_curso' | 'completada';
  codigo_http: number | null;
  cuerpo_respuesta: Jsonb;
  creada_en: Timestamp;
  expira_en: Timestamp;
}

export interface OutboxTable {
  id: string;
  modulo: string;
  tipo: string;
  agregado_id: string;
  carga: Jsonb;
  ocurrido_en: Timestamp;
  publicado_en: NullableTimestamp;
  intentos: WithDefault<number>;
}

/** Tables of the `compartido` schema: cross-cutting for every module. */
export interface SharedTables {
  'compartido.idempotencia': IdempotencyTable;
  'compartido.outbox': OutboxTable;
}
