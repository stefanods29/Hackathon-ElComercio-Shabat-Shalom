import { Inject, Injectable } from '@nestjs/common';
import { type Kysely, sql } from 'kysely';
import { KYSELY } from '../../../shared/db/connection.js';
import type {
  PublicService,
  ServiceSearchPage,
  ServiceSearchQuery,
  ServiceSearchReader,
} from '../application/search-ports.js';
import { publicDistanceMeters } from '../domain/distance.js';
import { serviceSearchQuery, type ServiceSearchRow } from './service-search.query.js';
import type { DirectoryTables } from './tables.js';

function toPublicService(row: ServiceSearchRow): PublicService {
  return {
    id: row.id,
    providerId: row.proveedor_id,
    zoneId: row.zona_id,
    categoryId: row.categoria_id,
    title: row.titulo,
    description: row.descripcion,
    publicLocation: { lat: row.lat_publica, lng: row.lng_publica },
    coverageRadiusMeters: row.radio_cobertura_m,
    availableInEmergency: row.disponible_en_emergencia,
    attributes: row.atributos,
    reviewCount: row.total_resenas,
    average: Number(row.promedio),
    rankingScore: Number(row.puntaje_ranking),
    zoneEndorsementCount: row.vistos_buenos_de_la_zona,
    version: row.version,
    createdAt: row.creado_en,
    updatedAt: row.actualizado_en,
    deletedAt: row.eliminado_en,
  };
}

@Injectable()
export class KyselyServiceSearchReader implements ServiceSearchReader {
  constructor(@Inject(KYSELY) private readonly db: Kysely<DirectoryTables>) {}

  async search(query: ServiceSearchQuery): Promise<ServiceSearchPage> {
    return this.db.transaction().execute(async (transaction) => {
      if (query.text) {
        await sql`SELECT set_config('pg_trgm.word_similarity_threshold', '0.3', true)`.execute(
          transaction,
        );
      }
      const { rows } = await serviceSearchQuery(query).execute(transaction);
      const data = rows.slice(0, query.limit).map((row) => ({
        service: toPublicService(row),
        distanceMeters: publicDistanceMeters(row.distancia_m),
      }));
      const last = data.at(-1)?.service;
      return {
        data,
        nextCursor:
          rows.length > query.limit && last
            ? { v: last.zoneEndorsementCount, p: last.rankingScore, id: last.id }
            : null,
      };
    });
  }
}
