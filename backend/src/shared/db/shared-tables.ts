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

/** Counters a phone sends at most once a day: no neighbor or device column (Lot A, part 3). */
export interface SyncTelemetryTable {
  id: WithDefault<string>;
  /** UTC day only (`YYYY-MM-DD`), so a row cannot be matched with a request. */
  recibido_el: string;
  version_app: string;
  sistema: 'android' | 'ios';
  duracion_periodo_minutos: number;
  cola_pendientes: number;
  envios_confirmados: number;
  tiempo_hasta_enviado_p50_segundos: number | null;
  tiempo_hasta_enviado_p95_segundos: number | null;
  rechazos_permanentes: Jsonb<Record<string, number>>;
  segundos_desde_ultima_sincronizacion: number | null;
  errores_de_conexion: number;
}

/** Tables of the `compartido` schema: cross-cutting for every module. */
export interface SharedTables {
  'compartido.idempotencia': IdempotencyTable;
  'compartido.outbox': OutboxTable;
  'compartido.telemetria_sincronizacion': SyncTelemetryTable;
}
