import type { GeneratedAlways } from 'kysely';
import type { Jsonb, NullableTimestamp, Timestamp, WithDefault } from '../../../shared/db/types.js';

export interface CategoriesTable {
  id: string;
  nombre: string;
  icono: string;
  util_en_emergencia: boolean;
  orden: number;
  actualizado_en: Timestamp;
}

export interface ProvidersTable {
  id: string;
  zona_id: string;
  nombre_publico: string;
  descripcion: string | null;
  creado_en: Timestamp;
  actualizado_en: Timestamp;
  eliminado_en: NullableTimestamp;
  oculto_en: NullableTimestamp;
}

export interface ServicesTable {
  id: string;
  proveedor_id: string;
  zona_id: string;
  categoria_id: string;
  titulo: string;
  descripcion: string | null;
  ubicacion: unknown;
  lat_publica: number;
  lng_publica: number;
  muestra_ubicacion_exacta: boolean;
  radio_cobertura_m: number;
  disponible_en_emergencia: boolean;
  atributos: Jsonb<Record<string, unknown>>;
  total_resenas: WithDefault<number>;
  suma_calificaciones: WithDefault<number>;
  promedio: WithDefault<string | number>;
  puntaje_ranking: WithDefault<string | number>;
  total_vistos_buenos: WithDefault<number>;
  vistos_buenos_de_la_zona: WithDefault<number>;
  version: number;
  creado_en: Timestamp;
  actualizado_en: Timestamp;
  eliminado_en: NullableTimestamp;
  oculto_en: NullableTimestamp;
  busqueda: GeneratedAlways<string>;
}

export interface DirectoryTables {
  'directorio.categorias': CategoriesTable;
  'directorio.proveedores': ProvidersTable;
  'directorio.servicios': ServicesTable;
}
