import { type Kysely, sql } from 'kysely';
import { inject } from 'vitest';
import {
  up as createSessions,
  down as dropSessions,
} from '../../src/modules/identidad/infrastructure/migrations/202611070200_identidad_sesiones.js';
import {
  up as createResidence,
  down as dropResidence,
} from '../../src/modules/identidad/infrastructure/migrations/202611080300_identidad_residencia_y_privacidad.js';
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
      WHERE schema_name IN ('compartido', 'directorio', 'emergencias', 'identidad', 'moderacion', 'reputacion', 'solidaridad')
      ORDER BY schema_name
    `.execute(db);
    expect(rows.map((row) => row.schema_name)).toEqual([
      'compartido',
      'directorio',
      'emergencias',
      'identidad',
      'moderacion',
      'reputacion',
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

  it('revierte y reaplica las tablas privadas de residencia sin recuperar un teléfono borrado', async () => {
    expect(inject('appliedMigrations')).toContain('202611080300_identidad_residencia_y_privacidad');
    const rollback = new Error('revertir prueba de migración');
    await expect(
      db.transaction().execute(async (transaction) => {
        const id = (
          await sql<{ id: string }>`
          INSERT INTO identidad.usuarios (telefono, nombre_visible, eliminado_en)
          VALUES (NULL, 'Cuenta eliminada', now()) RETURNING id
        `.execute(transaction)
        ).rows[0]!.id;

        await dropResidence(transaction);
        const removed = await sql<{ table_name: string }>`
          SELECT table_name FROM information_schema.tables WHERE table_schema = 'identidad'
          AND table_name IN ('consentimientos', 'presencias', 'avales', 'confirmaciones')
        `.execute(transaction);
        expect(removed.rows).toEqual([]);
        const tombstone = await sql<{ telefono: string; eliminado_en: Date }>`
          SELECT telefono, eliminado_en FROM identidad.usuarios WHERE id = ${id}
        `.execute(transaction);
        expect(tombstone.rows[0]).toMatchObject({
          telefono: expect.stringMatching(/^\+999[0-9]{12}$/),
          eliminado_en: expect.any(Date),
        });

        await createResidence(transaction);
        const restored = await sql<{ table_name: string }>`
          SELECT table_name FROM information_schema.tables WHERE table_schema = 'identidad'
          AND table_name IN ('consentimientos', 'presencias', 'avales', 'confirmaciones') ORDER BY 1
        `.execute(transaction);
        expect(restored.rows.map((row) => row.table_name)).toEqual([
          'avales',
          'confirmaciones',
          'consentimientos',
          'presencias',
        ]);
        throw rollback;
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
      'reputacion.resena_fotos',
      'reputacion.resenas',
      'reputacion.vistos_buenos',
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
