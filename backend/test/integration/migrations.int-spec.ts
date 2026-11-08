import { type Kysely, sql } from 'kysely';
import { inject } from 'vitest';
import {
  up as createSessions,
  down as dropSessions,
} from '../../src/modules/identidad/infrastructure/migrations/202611070200_identidad_sesiones.js';
import { createKysely } from '../../src/shared/db/connection.js';

describe('Migraciones de todos los módulos', () => {
  let db: Kysely<unknown>;

  beforeAll(() => {
    db = createKysely(inject('databaseUrl'), 1);
  });

  afterAll(async () => {
    await db.destroy();
  });

  it('se aplican en orden global y cada módulo crea su propio esquema', async () => {
    const applied = inject('appliedMigrations');
    expect(applied).toEqual([...applied].sort());
    expect(applied[0]).toMatch(/_compartido_base$/);

    const { rows } = await sql<{ schema_name: string }>`
      SELECT schema_name FROM information_schema.schemata
      WHERE schema_name IN ('compartido', 'directorio', 'emergencias', 'identidad', 'solidaridad')
      ORDER BY schema_name
    `.execute(db);
    expect(rows.map((row) => row.schema_name)).toEqual([
      'compartido',
      'directorio',
      'emergencias',
      'identidad',
      'solidaridad',
    ]);
  });

  it('uuidv7() genera UUID de versión 7 (nativa en PG18, compatible en versiones anteriores)', async () => {
    const { rows } = await sql<{ id: string }>`SELECT uuidv7()::text AS id`.execute(db);
    expect(rows[0]?.id).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
    );
  });

  it('la migración de sesiones se puede revertir y aplicar sin modificar los usuarios', async () => {
    const rollback = new Error('revertir prueba de migración');
    await expect(
      db.transaction().execute(async (transaction) => {
        await dropSessions(transaction);
        const absent = await sql<{
          name: string | null;
        }>`SELECT to_regclass('identidad.sesiones')::text AS name`.execute(transaction);
        expect(absent.rows).toEqual([{ name: null }]);
        await createSessions(transaction);
        const present = await sql<{
          name: string;
        }>`SELECT to_regclass('identidad.sesiones')::text AS name`.execute(transaction);
        expect(present.rows).toEqual([{ name: 'identidad.sesiones' }]);
        throw rollback; // Keep the suite's data: this entire round trip is rolled back.
      }),
    ).rejects.toBe(rollback);
  });

  it('la publicación de PowerSync incluye solo las tablas que deben llegar a los celulares', async () => {
    const { rows } = await sql<{ table_name: string }>`
      SELECT schemaname || '.' || tablename AS table_name FROM pg_publication_tables
      WHERE pubname = 'powersync' ORDER BY 1
    `.execute(db);
    expect(rows.map((row) => row.table_name)).toEqual([
      'directorio.categorias',
      'directorio.proveedores',
      'directorio.servicios',
      'emergencias.asignaciones',
      'emergencias.pedidos_ayuda',
      'identidad.zonas',
      'solidaridad.publicaciones',
    ]);
  });

  it('la base protege las reglas aunque falle el código: nadie toma su propio favor', async () => {
    await expect(
      sql`
        INSERT INTO solidaridad.publicaciones (id, autor_id, zona_id, tipo, categoria, titulo, tomada_por_id)
        VALUES (uuidv7(), '01970000-0000-7000-8000-0000000000a1', '01970000-0000-7000-8000-000000000001',
                'presto', 'herramientas', 'Presto escalera', '01970000-0000-7000-8000-0000000000a1')
      `.execute(db),
    ).rejects.toThrow(/check/i);
  });
});
