import type { TransactionContext } from '../../../shared/db/unit-of-work.js';

export interface ServiceForReputation {
  readonly providerId: string;
  readonly zoneId: string;
  readonly active: boolean;
}

export interface DirectoryServiceReader {
  findForReputation(
    transaction: TransactionContext,
    serviceId: string,
  ): Promise<ServiceForReputation | null>;
}

export const DIRECTORY_SERVICE_READER = Symbol('DIRECTORY_SERVICE_READER');

export interface AggregateSnapshot {
  readonly servicioId: string;
  readonly totalResenas: number;
  readonly sumaCalificaciones: number;
  readonly totalVistosBuenos: number;
  readonly vistosBuenosDeLaZona: number;
}

export interface AggregateVersion {
  readonly eventId: string;
  readonly occurredAt: string;
}

export interface CategoryRatingFacts {
  readonly id: string;
  readonly reviewCount: number;
  readonly ratingSum: number;
}

export interface DirectoryRankingStore {
  applyFacts(
    transaction: TransactionContext,
    facts: AggregateSnapshot,
    version: AggregateVersion,
    now: Date,
  ): Promise<string | null>;
  categoryFacts(
    transaction: TransactionContext,
    categoryId: string,
  ): Promise<CategoryRatingFacts[]>;
  saveScores(
    transaction: TransactionContext,
    categoryId: string,
    scores: readonly { id: string; score: number }[],
    now: Date,
  ): Promise<void>;
}

export const DIRECTORY_RANKING_STORE = Symbol('DIRECTORY_RANKING_STORE');
