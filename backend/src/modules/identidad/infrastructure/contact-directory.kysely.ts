import { Inject, Injectable } from '@nestjs/common';
import { type Kysely, sql } from 'kysely';
import { KYSELY } from '../../../shared/db/connection.js';
import type { ContactDirectory } from '../application/contact-directory.js';

/** Identity owns `identidad.usuarios`: other modules ask through this port, never by SQL. */
@Injectable()
export class KyselyContactDirectory implements ContactDirectory {
  constructor(@Inject(KYSELY) private readonly db: Kysely<unknown>) {}

  async phoneOf(userId: string): Promise<string | null> {
    const result = await sql<{ telefono: string }>`SELECT telefono FROM identidad.usuarios
      WHERE id = ${userId}::uuid`.execute(this.db);
    return result.rows[0]?.telefono ?? null;
  }
}
