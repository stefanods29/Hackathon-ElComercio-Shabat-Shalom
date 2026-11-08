import type { NullableTimestamp, Timestamp, WithDefault } from '../../../shared/db/types.js';
import type { ReviewState } from '../domain/review.js';

export interface ReviewsTable {
  id: string;
  servicio_id: string;
  autor_id: string;
  zona_autor_id: string;
  calificacion: number;
  comentario: string | null;
  estado: ReviewState;
  motivo_estado: string | null;
  creado_en: Timestamp;
  actualizado_en: Timestamp;
  publicada_en: NullableTimestamp;
}

export interface ReviewPhotosTable {
  id: WithDefault<string>;
  resena_id: string;
  archivo_id: string;
  orden: number;
  ancho: number;
  alto: number;
  blurhash: string | null;
  oculta_en: NullableTimestamp;
}

export interface EndorsementsTable {
  id: WithDefault<string>;
  servicio_id: string;
  vecino_id: string;
  nivel_al_dar: number;
  zona_vecino_id: string;
  creado_en: Timestamp;
}

export interface ReviewSignalsTable {
  resena_id: string;
  dispositivo_hash: string;
  creado_en: Timestamp;
}

export interface ReputationTables {
  'reputacion.resenas': ReviewsTable;
  'reputacion.resena_fotos': ReviewPhotosTable;
  'reputacion.vistos_buenos': EndorsementsTable;
  'reputacion.senales_resenas': ReviewSignalsTable;
}
