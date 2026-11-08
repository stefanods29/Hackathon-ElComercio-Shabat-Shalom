import { type Kysely, sql } from 'kysely';
import { inject } from 'vitest';
import {
  up as createEmergencyProjections,
  down as dropEmergencyProjections,
} from '../../src/modules/emergencias/infrastructure/migrations/202611160100_emergencias_streams_operativos.js';
import { up as backfillEmergencyLocations } from '../../src/modules/emergencias/infrastructure/migrations/202611160110_emergencias_relleno_ubicaciones.js';
import {
  up as createSessions,
  down as dropSessions,
} from '../../src/modules/identidad/infrastructure/migrations/202611070200_identidad_sesiones.js';
import {
  up as createResidence,
  down as dropResidence,
} from '../../src/modules/identidad/infrastructure/migrations/202611080300_identidad_residencia_y_privacidad.js';
import {
  up as createModeration,
  down as dropModeration,
} from '../../src/modules/moderacion/infrastructure/migrations/202611080400_moderacion_denuncias_decisiones_y_sanciones.js';
import {
  up as addWallVisibility,
  down as dropWallVisibility,
} from '../../src/modules/solidaridad/infrastructure/migrations/202611080410_solidaridad_visibilidad_moderacion.js';
import {
  up as addServiceVisibility,
  down as dropServiceVisibility,
} from '../../src/modules/directorio/infrastructure/migrations/202611080420_directorio_visibilidad_individual.js';
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

  it('repone la ubicación de pedidos en camino previos a los streams y conserva su purga', async () => {
    const rollback = new Error('revertir prueba de migración');
    await expect(
      db.transaction().execute(async (tx) => {
        await dropEmergencyProjections(tx);
        const { rows } = await sql<{ id: string; vigente: boolean }>`
          INSERT INTO emergencias.pedidos_ayuda (detalle, estado, creado_en, vence_en)
          VALUES
            ('Solicitud ficticia', 'en_camino', now() - interval '2 hours', now() + interval '1 hour'),
            ('Solicitud ficticia vencida', 'en_camino', now() - interval '2 hours', now() - interval '1 hour')
          RETURNING id, vence_en > now() AS vigente
        `.execute(tx);
        const current = rows.find(({ vigente }) => vigente)!.id;
        for (const { id } of rows) {
          await sql`
            INSERT INTO emergencias.detalles_pedidos (pedido_id, descripcion, lat, lng)
            VALUES (${id}, 'Detalle ficticio', -12.08, -77.03)
          `.execute(tx);
        }
        await createEmergencyProjections(tx);
        const copies = async () =>
          (
            await sql`
              SELECT pedido_id, lat, lng FROM emergencias.ubicaciones_en_camino
              WHERE pedido_id = ANY(${sql.val(rows.map(({ id }) => id))}::uuid[])
            `.execute(tx)
          ).rows;
        expect(await copies()).toEqual([]);
        await backfillEmergencyLocations(tx);
        await backfillEmergencyLocations(tx);
        expect(await copies()).toEqual([{ pedido_id: current, lat: -12.08, lng: -77.03 }]);
        await sql`UPDATE emergencias.pedidos_ayuda SET estado = 'atendido' WHERE id = ${current}`.execute(
          tx,
        );
        expect(await copies()).toEqual([]);
        throw rollback;
      }),
    ).rejects.toBe(rollback);
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

  it('revierte y reaplica moderación sin publicar sus tablas privadas', async () => {
    expect(inject('appliedMigrations')).toEqual(
      expect.arrayContaining([
        '202611080400_moderacion_denuncias_decisiones_y_sanciones',
        '202611080410_solidaridad_visibilidad_moderacion',
        '202611080420_directorio_visibilidad_individual',
      ]),
    );
    const rollback = new Error('revertir prueba de migración');
    await expect(
      db.transaction().execute(async (tx) => {
        await dropServiceVisibility(tx);
        await dropWallVisibility(tx);
        await dropModeration(tx);
        const read = () =>
          sql<{ denuncias: string | null; muro: boolean; servicios: boolean }>`
        SELECT to_regclass('moderacion.denuncias')::text AS denuncias,
          EXISTS (SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'solidaridad' AND table_name = 'publicaciones' AND column_name = 'oculta_en') AS muro,
          EXISTS (SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'directorio' AND table_name = 'servicios' AND column_name = 'oculto_individual_en') AS servicios
      `.execute(tx);
        expect((await read()).rows).toEqual([{ denuncias: null, muro: false, servicios: false }]);
        await createModeration(tx);
        await addWallVisibility(tx);
        await addServiceVisibility(tx);
        expect((await read()).rows).toEqual([
          { denuncias: 'moderacion.denuncias', muro: true, servicios: true },
        ]);
        const published = await sql`SELECT tablename FROM pg_publication_tables
        WHERE pubname = 'powersync' AND schemaname = 'moderacion'`.execute(tx);
        expect(published.rows).toEqual([]);
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
      'emergencias.agregados_celda',
      'emergencias.asignaciones',
      'emergencias.autorizaciones_stream',
      'emergencias.historial_para_autor',
      'emergencias.pedidos_ayuda',
      'emergencias.recursos_publicos',
      'emergencias.ubicaciones_en_camino',
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
