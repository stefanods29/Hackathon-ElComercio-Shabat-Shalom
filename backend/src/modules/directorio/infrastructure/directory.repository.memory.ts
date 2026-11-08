import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import type { Category, DirectoryRepository } from '../application/ports.js';
import { ProviderProfile, type ProviderProps } from '../domain/provider-profile.js';
import { Service, type ServiceProps } from '../domain/service.js';

export class InMemoryDirectoryRepository implements DirectoryRepository {
  private readonly providers = new Map<string, ProviderProps>();
  private readonly services = new Map<string, ServiceProps>();

  constructor(
    private readonly categories: Category[] = [
      {
        id: 'gasfiteria',
        name: 'Gasfitería',
        icon: 'plumbing',
        usefulInEmergency: true,
        order: 10,
      },
    ],
  ) {}

  async listCategories(): Promise<Category[]> {
    return structuredClone(this.categories).sort(
      (left, right) => left.order - right.order || left.id.localeCompare(right.id),
    );
  }

  async categoryExists(_transaction: TransactionContext, id: string): Promise<boolean> {
    return this.categories.some((category) => category.id === id);
  }

  async lockProvider(_transaction: TransactionContext, _id: string): Promise<void> {}

  async findProvider(
    _transaction: TransactionContext,
    id: string,
  ): Promise<ProviderProfile | null> {
    const row = this.providers.get(id);
    return row ? ProviderProfile.restore(row) : null;
  }

  async saveProvider(_transaction: TransactionContext, provider: ProviderProfile): Promise<void> {
    const data = provider.snapshot();
    this.providers.set(data.id, data);
  }

  async findService(_transaction: TransactionContext, id: string): Promise<Service | null> {
    const row = this.services.get(id);
    return row ? Service.restore(row) : null;
  }

  async insertService(_transaction: TransactionContext, service: Service): Promise<boolean> {
    if (this.services.has(service.id)) return false;
    this.services.set(service.id, service.snapshot());
    return true;
  }

  async updateService(
    _transaction: TransactionContext,
    service: Service,
    previousVersion: number,
  ): Promise<boolean> {
    const current = this.services.get(service.id);
    if (!current || current.version !== previousVersion || current.deletedAt) return false;
    this.services.set(service.id, service.snapshot());
    return true;
  }

  async listPublicServices(
    _transaction: TransactionContext,
    providerId: string,
    zoneId: string,
  ): Promise<ServiceProps[]> {
    return [...this.services.values()]
      .filter(
        (row) =>
          row.providerId === providerId && row.zoneId === zoneId && !row.deletedAt && !row.hiddenAt,
      )
      .sort((left, right) => left.id.localeCompare(right.id))
      .map((row) => structuredClone(row));
  }

  async withdrawInZone(
    _transaction: TransactionContext,
    providerId: string,
    zoneId: string,
    now: Date,
  ): Promise<void> {
    for (const row of this.services.values()) {
      if (row.providerId === providerId && row.zoneId === zoneId && !row.deletedAt) {
        const service = Service.restore(row);
        service.withdraw(providerId, now);
        this.services.set(row.id, service.snapshot());
      }
    }
  }

  forceService(props: ServiceProps): void {
    this.services.set(props.id, structuredClone(props));
  }

  forceProvider(props: ProviderProps): void {
    this.providers.set(props.id, structuredClone(props));
  }
}
