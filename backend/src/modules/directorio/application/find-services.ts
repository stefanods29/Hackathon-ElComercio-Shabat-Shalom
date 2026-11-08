import { Inject, Injectable } from '@nestjs/common';
import { BusinessRuleViolation } from '../../../shared/domain/errors.js';
import type { Coordinates } from '../domain/service.js';
import type { DirectoryActor } from './ports.js';
import { decodeServiceCursor, encodeServiceCursor } from './service-cursor.js';
import {
  SERVICE_SEARCH_READER,
  type ServiceSearchHit,
  type ServiceSearchReader,
} from './search-ports.js';

export interface FindServicesQuery {
  readonly location: Coordinates;
  readonly radiusMeters: number;
  readonly categoryId?: string;
  readonly text?: string;
  readonly emergencyOnly: boolean;
  readonly cursor?: string;
  readonly limit: number;
}

@Injectable()
export class FindServices {
  constructor(@Inject(SERVICE_SEARCH_READER) private readonly reader: ServiceSearchReader) {}

  async execute(
    query: FindServicesQuery,
    actor: DirectoryActor,
  ): Promise<{ data: ServiceSearchHit[]; nextCursor: string | null }> {
    if (!actor.zoneId) {
      throw new BusinessRuleViolation(
        'sin_zona',
        'Elige tu zona antes de buscar servicios.',
        'forbidden',
      );
    }
    const page = await this.reader.search({
      ...query,
      zoneId: actor.zoneId,
      cursor: query.cursor !== undefined ? decodeServiceCursor(query.cursor) : null,
    });
    return {
      data: page.data,
      nextCursor: page.nextCursor ? encodeServiceCursor(page.nextCursor) : null,
    };
  }
}
