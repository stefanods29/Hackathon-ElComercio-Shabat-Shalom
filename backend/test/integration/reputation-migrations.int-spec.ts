import { type Kysely, sql } from 'kysely';
import { inject } from 'vitest';
import {
  up as createRankingControl,
  down as dropRankingControl,
} from '../../src/modules/directorio/infrastructure/migrations/202611080210_directorio_control_recalculo.js';
import {
  up as createCases,
  down as dropCases,
} from '../../src/modules/moderacion/infrastructure/migrations/202611080220_moderacion_casos.js';
import {
  up as createReports,
  down as dropReports,
} from '../../src/modules/moderacion/infrastructure/migrations/202611080400_moderacion_denuncias_decisiones_y_sanciones.js';
import {
  up as createReputation,
  down as dropReputation,
} from '../../src/modules/reputacion/infrastructure/migrations/202611080200_reputacion_base.js';
import { createKysely } from '../../src/shared/db/connection.js';

const PUBLIC_TABLES = ['reputacion.resena_fotos', 'reputacion.resenas', 'reputacion.vistos_buenos'];
const PRIVATE_TABLES = [
  'reputacion.senales_resenas',
  'moderacion.casos',
  'directorio.recalculos_reputacion',
];

describe('Migraciones de reputación y antifraude', () => {
  let db: Kysely<unknown>;
  beforeAll(() => {
    db = createKysely(inject('databaseUrl'), 1);
  });
  afterAll(async () => {
    await db.destroy();
  });

  it('publica las tres tablas acordadas y excluye señales, casos y control de eventos', async () => {
    const { rows } = await sql<{ name: string }>`
      SELECT schemaname || '.' || tablename AS name FROM pg_publication_tables
      WHERE pubname = 'powersync'
        AND (schemaname = 'reputacion' OR (schemaname || '.' || tablename) = ANY(${PRIVATE_TABLES}::text[]))
      ORDER BY 1
    `.execute(db);
    expect(rows.map((row) => row.name)).toEqual(PUBLIC_TABLES);
    const role = await sql<{
      present: boolean;
    }>`SELECT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'powersync_rol') AS present`.execute(
      db,
    );
    if (role.rows[0]?.present) {
      for (const table of PUBLIC_TABLES) {
        const permission = await sql<{
          allowed: boolean;
        }>`SELECT has_table_privilege('powersync_rol', ${table}, 'SELECT') AS allowed`.execute(db);
        expect(permission.rows[0]?.allowed).toBe(true);
      }
    }
  });

  it('revierte y reaplica las tres migraciones sin afectar las tablas del directorio', async () => {
    const rollback = new Error('revertir prueba de migración');
    await expect(
      db.transaction().execute(async (transaction) => {
        const serviceCount = () =>
          sql<{ count: number }>`SELECT count(*)::int AS count FROM directorio.servicios`.execute(
            transaction,
          );
        const before = await serviceCount();
        // Reports, decisions and sanctions (part 5) reference the cases: they go first.
        await dropReports(transaction);
        await dropCases(transaction);
        await dropRankingControl(transaction);
        await dropReputation(transaction);
        for (const table of [...PUBLIC_TABLES, ...PRIVATE_TABLES]) {
          const absent = await sql<{
            name: string | null;
          }>`SELECT to_regclass(${table})::text AS name`.execute(transaction);
          expect(absent.rows).toEqual([{ name: null }]);
        }
        await createReputation(transaction);
        await createRankingControl(transaction);
        await createCases(transaction);
        await createReports(transaction);
        for (const table of [...PUBLIC_TABLES, ...PRIVATE_TABLES]) {
          const present = await sql<{
            name: string;
          }>`SELECT to_regclass(${table})::text AS name`.execute(transaction);
          expect(present.rows).toEqual([{ name: table }]);
        }
        expect((await serviceCount()).rows).toEqual(before.rows);
        throw rollback;
      }),
    ).rejects.toBe(rollback);
  });
});
