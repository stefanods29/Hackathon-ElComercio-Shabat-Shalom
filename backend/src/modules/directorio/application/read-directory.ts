import { Inject, Injectable } from '@nestjs/common';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { ResourceNotFound } from '../../../shared/domain/errors.js';
import type { ProviderProps } from '../domain/provider-profile.js';
import type { ServiceProps } from '../domain/service.js';
import { DIRECTORY_REPOSITORY, type Category, type DirectoryRepository } from './ports.js';

@Injectable()
export class ReadDirectory {
  constructor(
    @Inject(UNIT_OF_WORK) private readonly unitOfWork: UnitOfWork,
    @Inject(DIRECTORY_REPOSITORY) private readonly directory: DirectoryRepository,
  ) {}

  categories(): Promise<Category[]> {
    return this.directory.listCategories();
  }

  async provider(id: string): Promise<{ provider: ProviderProps; services: ServiceProps[] }> {
    return this.unitOfWork.run(async (transaction) => {
      const profile = (await this.directory.findProvider(transaction, id))?.snapshot();
      if (!profile || profile.deletedAt || profile.hiddenAt) {
        throw new ResourceNotFound('el proveedor', id);
      }
      return {
        provider: profile,
        services: await this.directory.listPublicServices(transaction, id, profile.zoneId),
      };
    });
  }
}
