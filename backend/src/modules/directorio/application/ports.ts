import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import type { ProviderProfile } from '../domain/provider-profile.js';
import type { Service, ServiceProps } from '../domain/service.js';

export interface DirectoryActor {
  readonly id: string;
  readonly zoneId: string | null;
  readonly trustLevel: number;
}

export interface Category {
  readonly id: string;
  readonly name: string;
  readonly icon: string;
  readonly usefulInEmergency: boolean;
  readonly order: number;
}

export interface DirectoryRepository {
  listCategories(): Promise<Category[]>;
  categoryExists(transaction: TransactionContext, id: string): Promise<boolean>;
  lockProvider(transaction: TransactionContext, id: string): Promise<void>;
  findProvider(transaction: TransactionContext, id: string): Promise<ProviderProfile | null>;
  saveProvider(transaction: TransactionContext, provider: ProviderProfile): Promise<void>;
  findService(transaction: TransactionContext, id: string): Promise<Service | null>;
  insertService(transaction: TransactionContext, service: Service): Promise<boolean>;
  updateService(
    transaction: TransactionContext,
    service: Service,
    previousVersion: number,
  ): Promise<boolean>;
  listPublicServices(
    transaction: TransactionContext,
    providerId: string,
    zoneId: string,
  ): Promise<ServiceProps[]>;
  withdrawInZone(
    transaction: TransactionContext,
    providerId: string,
    zoneId: string,
    now: Date,
  ): Promise<void>;
}

export const DIRECTORY_REPOSITORY = Symbol('DIRECTORY_REPOSITORY');
