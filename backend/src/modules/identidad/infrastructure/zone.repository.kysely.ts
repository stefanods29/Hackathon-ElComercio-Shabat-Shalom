import { Inject, Injectable } from '@nestjs/common';
import type { Kysely } from 'kysely';
import { KYSELY } from '../../../shared/db/connection.js';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import { asKysely } from '../../../shared/db/unit-of-work.kysely.js';
import type { ZoneRepository, ZoneSummary } from '../application/ports.js';
import type { IdentityTables } from './tables.js';

@Injectable()
export class KyselyZoneRepository implements ZoneRepository {
  constructor(@Inject(KYSELY) private readonly db: Kysely<IdentityTables>) {}

  async list(): Promise<ZoneSummary[]> {
    const rows = await this.db
      .selectFrom('identidad.zonas')
      .select(['id', 'nombre', 'distrito'])
      .orderBy('nombre')
      .orderBy('id')
      .execute();
    return rows.map((row) => ({ id: row.id, name: row.nombre, district: row.distrito }));
  }

  async exists(transaction: TransactionContext, id: string): Promise<boolean> {
    const row = await asKysely<IdentityTables>(transaction)
      .selectFrom('identidad.zonas')
      .select('id')
      .where('id', '=', id)
      .executeTakeFirst();
    return row !== undefined;
  }
}
