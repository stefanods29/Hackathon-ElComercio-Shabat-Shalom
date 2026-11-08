import { Injectable } from '@nestjs/common';
import { sql } from 'kysely';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import { asJsonb, asKysely } from '../../../shared/db/unit-of-work.kysely.js';
import type { DirectoryVersionRecord, DirectoryVersionStore } from '../application/ports.js';

@Injectable()
export class DirectoryVersionRepository implements DirectoryVersionStore {
  async lock(transaction: TransactionContext, archivo: string): Promise<void> {
    await sql`SELECT pg_advisory_xact_lock(hashtext(${'curaduria:' + archivo}))`.execute(
      asKysely<unknown>(transaction),
    );
  }

  async latest(transaction: TransactionContext, archivo: string): Promise<number | null> {
    const result = await sql<{ version: number | null }>`SELECT max(version) AS version
      FROM curaduria.versiones_directorio WHERE archivo = ${archivo}`.execute(
      asKysely<unknown>(transaction),
    );
    return result.rows[0]?.version ?? null;
  }

  async insert(transaction: TransactionContext, record: DirectoryVersionRecord): Promise<void> {
    await sql`INSERT INTO curaduria.versiones_directorio
        (archivo, version, contenido, sha256, bytes, publicado_por, publicado_en)
      VALUES (${record.archivo}, ${record.version}, ${asJsonb(record.contenido)}, ${record.sha256},
        ${record.bytes}, ${record.publicadoPor}::uuid, ${record.publicadoEn}::timestamptz)`.execute(
      asKysely<unknown>(transaction),
    );
  }
}
