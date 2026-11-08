import type { ServiceProps, Coordinates } from '../domain/service.js';

export type PublicService = Omit<
  ServiceProps,
  'location' | 'showExactLocation' | 'ratingSum' | 'endorsementCount' | 'hiddenAt'
>;

export interface ServiceCursor {
  readonly v: number;
  readonly p: number;
  readonly id: string;
}

export interface ServiceSearchQuery {
  readonly location: Coordinates;
  readonly radiusMeters: number;
  readonly zoneId: string;
  readonly categoryId?: string;
  readonly text?: string;
  readonly emergencyOnly: boolean;
  readonly cursor: ServiceCursor | null;
  readonly limit: number;
}

export interface ServiceSearchHit {
  readonly service: PublicService;
  readonly distanceMeters: number;
}

export interface ServiceSearchPage {
  readonly data: ServiceSearchHit[];
  readonly nextCursor: ServiceCursor | null;
}

export interface ServiceSearchReader {
  search(query: ServiceSearchQuery): Promise<ServiceSearchPage>;
}

export const SERVICE_SEARCH_READER = Symbol('SERVICE_SEARCH_READER');
