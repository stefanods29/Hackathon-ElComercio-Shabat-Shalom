import { Injectable } from '@nestjs/common';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import { asKysely } from '../../../shared/db/unit-of-work.kysely.js';
import type { AuthorTrust } from '../application/author-trust.js';
import type { IdentityTables } from './tables.js';

@Injectable()
export class KyselyAuthorTrust implements AuthorTrust {
  async trustLevel(tx: TransactionContext, userId: string): Promise<number | null> {
    const user = await asKysely<IdentityTables>(tx)
      .selectFrom('identidad.usuarios')
      .select('nivel_confianza')
      .where('id', '=', userId)
      .where('eliminado_en', 'is', null)
      .executeTakeFirst();
    return user?.nivel_confianza ?? null;
  }
}
