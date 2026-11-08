import { type Kysely, sql } from 'kysely';
import { inject } from 'vitest';
import {
  up,
  down,
} from '../../src/modules/directorio/infrastructure/migrations/202611080100_directorio_base.js';
import {
  up as createSearch,
  down as dropSearch,
} from '../../src/modules/directorio/infrastructure/migrations/202611080110_directorio_busqueda.js';
import { createKysely } from '../../src/shared/db/connection.js';

const TABLES = ['categorias', 'proveedores', 'servicios'];

describe('Migración del directorio', () => {
  let db: Kysely<unknown>;
  beforeAll(() => {
    db = createKysely(inject('databaseUrl'), 1);
  });
  afterAll(async () => {
    await db.destroy();
  });

  it('publica solo sus tres tablas y concede lectura cuando powersync_rol existe', async () => {
    const { rows } = await sql<{ table_name: string }>`
      SELECT tablename AS table_name FROM pg_publication_tables
      WHERE pubname = 'powersync' AND schemaname = 'directorio' ORDER BY tablename
    `.execute(db);
    expect(rows.map((row) => row.table_name)).toEqual(TABLES);
    const roles = await sql<{ present: boolean }>`
      SELECT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'powersync_rol') AS present
    `.execute(db);
    if (roles.rows[0]?.present) {
      for (const table of TABLES) {
        const grants = await sql<{ allowed: boolean }>`
          SELECT has_table_privilege('powersync_rol', ${`directorio.${table}`}, 'SELECT') AS allowed
        `.execute(db);
        expect(grants.rows[0]?.allowed).toBe(true);
      }
    }
  });

  it('revierte y aplica sin dejar tablas ni entradas de publicación y vuelve a sembrar categorías', async () => {
    const rollback = new Error('revertir la prueba de migración');
    await expect(
      db.transaction().execute(async (transaction) => {
        await dropSearch(transaction);
        await down(transaction);
        const absent = await sql<{ name: string | null }>`
        SELECT to_regclass('directorio.servicios')::text AS name
      `.execute(transaction);
        expect(absent.rows).toEqual([{ name: null }]);
        const publication = await sql<{ count: number }>`
        SELECT count(*)::int AS count FROM pg_publication_tables
        WHERE pubname = 'powersync' AND schemaname = 'directorio'
      `.execute(transaction);
        expect(publication.rows[0]?.count).toBe(0);
        await up(transaction);
        await createSearch(transaction);
        const categories = await sql<{ id: string; icono: string; util_en_emergencia: boolean }>`
        SELECT id, icono, util_en_emergencia FROM directorio.categorias WHERE id = 'gasfiteria'
      `.execute(transaction);
        expect(categories.rows).toEqual([
          { id: 'gasfiteria', icono: 'plumbing', util_en_emergencia: true },
        ]);
        throw rollback;
      }),
    ).rejects.toBe(rollback);
  });
});
