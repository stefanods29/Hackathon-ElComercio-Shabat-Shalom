import type { NullableTimestamp, Timestamp, WithDefault } from '../../../shared/db/types.js';
import type { PostStatus, PostType } from '../domain/post.js';

/** Table and column names follow the database schema (Spanish), as the architecture sets. */
export interface PostsTable {
  id: string;
  autor_id: string;
  zona_id: string;
  tipo: PostType;
  categoria: string;
  titulo: string;
  descripcion: string | null;
  lat: number | null;
  lng: number | null;
  /** geography(Point): computed in the INSERT from lat/lng. */
  ubicacion: unknown;
  estado: PostStatus;
  tomada_por_id: string | null;
  version: number;
  vence_en: NullableTimestamp;
  creado_en: Timestamp;
  actualizado_en: Timestamp;
  eliminado_en: NullableTimestamp;
  oculta_en: NullableTimestamp;
}

/** Tables of the `solidaridad` schema. Only the Solidarity module queries them. */
export interface SolidarityTables {
  'solidaridad.publicaciones': PostsTable & { version: WithDefault<number> };
}
