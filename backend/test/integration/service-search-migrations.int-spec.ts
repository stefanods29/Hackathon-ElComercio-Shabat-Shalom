import { type Kysely, sql } from 'kysely';
import { inject } from 'vitest';
import {
  up,
  down,
} from '../../src/modules/directorio/infrastructure/migrations/202611080110_directorio_busqueda.js';
import { createKysely } from '../../src/shared/db/connection.js';

const INDEXES = ['servicios_busqueda_gin', 'servicios_orden_idx', 'servicios_titulo_trgm_gin'];

describe('Migración de búsqueda del directorio', () => {
  let db: Kysely<unknown>;
  beforeAll(() => {
    db = createKysely(inject('databaseUrl'), 1);
  });
  afterAll(async () => {
    await db.destroy();
  });

  it('crea sin_tildes IMMUTABLE, el tsvector generado y los índices de texto y orden', async () => {
    const functionInfo = await sql<{ volatility: string; normalized: string }>`
      SELECT p.provolatile AS volatility, directorio.sin_tildes('Gásfitería') AS normalized
      FROM pg_proc p WHERE p.oid = 'directorio.sin_tildes(text)'::regprocedure
    `.execute(db);
    expect(functionInfo.rows).toEqual([{ volatility: 'i', normalized: 'Gasfiteria' }]);
    const column = await sql<{ generated: string; type: string }>`
      SELECT a.attgenerated AS generated, format_type(a.atttypid, a.atttypmod) AS type
      FROM pg_attribute a WHERE a.attrelid = 'directorio.servicios'::regclass AND a.attname = 'busqueda'
    `.execute(db);
    expect(column.rows).toEqual([{ generated: 's', type: 'tsvector' }]);
    const indexes = await sql<{ indexname: string }>`
      SELECT indexname FROM pg_indexes WHERE schemaname = 'directorio' AND indexname = ANY(${INDEXES}::text[])
      ORDER BY indexname
    `.execute(db);
    expect(indexes.rows.map((row) => row.indexname)).toEqual(INDEXES);
  });

  it('revierte y aplica sin perder servicios ni cambiar las tablas publicadas', async () => {
    const rollback = new Error('revertir prueba de búsqueda');
    await expect(
      db.transaction().execute(async (transaction) => {
        const before = await sql<{
          count: number;
        }>`SELECT count(*)::int AS count FROM directorio.servicios`.execute(transaction);
        await down(transaction);
        const absent = await sql<{
          name: string | null;
        }>`SELECT to_regprocedure('directorio.sin_tildes(text)')::text AS name`.execute(
          transaction,
        );
        expect(absent.rows).toEqual([{ name: null }]);
        await up(transaction);
        const after = await sql<{
          count: number;
        }>`SELECT count(*)::int AS count FROM directorio.servicios`.execute(transaction);
        expect(after.rows).toEqual(before.rows);
        const missing = await sql<{
          count: number;
        }>`SELECT count(*)::int AS count FROM directorio.servicios WHERE busqueda IS NULL`.execute(
          transaction,
        );
        expect(missing.rows[0]?.count).toBe(0);
        const published = await sql<{ tablename: string }>`
        SELECT tablename FROM pg_publication_tables WHERE pubname = 'powersync' AND schemaname = 'directorio' ORDER BY tablename
      `.execute(transaction);
        expect(published.rows.map((row) => row.tablename)).toEqual([
          'categorias',
          'proveedores',
          'servicios',
        ]);
        throw rollback;
      }),
    ).rejects.toBe(rollback);
  });
});
