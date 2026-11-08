import type { INestApplication } from '@nestjs/common';
import { type Kysely, sql } from 'kysely';
import request from 'supertest';
import { inject } from 'vitest';
import { DEMO_SERVICES, NEIGHBORS, PILOT_ZONE } from '../../scripts/seed-data.js';
import { KyselyServiceSearchReader } from '../../src/modules/directorio/infrastructure/service-search.reader.kysely.js';
import type { DirectoryTables } from '../../src/modules/directorio/infrastructure/tables.js';
import { createKysely } from '../../src/shared/db/connection.js';
import { newId } from '../../src/shared/domain/ids.js';
import { HttpRequestLogger } from '../../src/shared/observability/request-id.middleware.js';
import { createTestApp } from '../support/app.js';

const NOW = new Date('2026-11-08T02:00:00Z');
const ORIGIN = { lat: -12.085678, lng: -77.034567 };
interface Fixture {
  zoneId: string;
  providerId: string;
  phone: string;
  token: string;
}
interface FixtureService {
  id?: string;
  title?: string;
  description?: string | null;
  categoryId?: string;
  emergency?: boolean;
  offsetMeters?: number;
  endorsements?: number;
  score?: number;
}

describe('Búsqueda de servicios con PostGIS y texto', () => {
  let app: INestApplication;
  let db: Kysely<unknown>;
  let sequence = 0;
  const server = () => app.getHttpServer();
  const search = (fixture: Pick<Fixture, 'token'>, query: Record<string, unknown> = {}) =>
    request(server())
      .get('/v1/servicios')
      .auth(fixture.token, { type: 'bearer' })
      .query({
        lat: ORIGIN.lat,
        lng: ORIGIN.lng,
        ...query,
      });

  async function signIn(phone: string): Promise<string> {
    const response = await request(server())
      .post('/v1/dev/sesiones')
      .send({ telefono: phone })
      .expect(201);
    return response.body.tokenDeAcceso as string;
  }

  async function fixture(): Promise<Fixture> {
    const zoneId = newId();
    const providerId = newId();
    const phone = `+5191820${String(++sequence).padStart(4, '0')}`;
    await sql`
      INSERT INTO identidad.zonas (id, nombre, distrito, limite)
      VALUES (${zoneId}, 'Zona de prueba de búsqueda', 'Lince (demo)', ST_GeogFromText(${PILOT_ZONE.boundaryWkt}))
    `.execute(db);
    await sql`
      INSERT INTO identidad.usuarios (id, telefono, nombre_visible, zona_id, nivel_confianza, roles)
      VALUES (${providerId}, ${phone}, 'Vecino de prueba de búsqueda', ${zoneId}, 1, '{}'::text[])
    `.execute(db);
    await sql`
      INSERT INTO directorio.proveedores (id, zona_id, nombre_publico, creado_en, actualizado_en)
      VALUES (${providerId}, ${zoneId}, 'Proveedor de prueba', ${NOW}, ${NOW})
    `.execute(db);
    return { zoneId, providerId, phone, token: await signIn(phone) };
  }

  async function insert(owner: Fixture, data: FixtureService = {}): Promise<string> {
    const id = data.id ?? newId();
    const point = sql`ST_Project(ST_SetSRID(ST_MakePoint(${ORIGIN.lng}, ${ORIGIN.lat}), 4326)::geography, ${data.offsetMeters ?? 0}, pi() / 2)`;
    await sql`
      INSERT INTO directorio.servicios (
        id, proveedor_id, zona_id, categoria_id, titulo, descripcion, ubicacion,
        lat_publica, lng_publica, disponible_en_emergencia, vistos_buenos_de_la_zona,
        puntaje_ranking, creado_en, actualizado_en
      ) VALUES (
        ${id}, ${owner.providerId}, ${owner.zoneId}, ${data.categoryId ?? 'gasfiteria'},
        ${data.title ?? 'Gasfitero a domicilio'}, ${data.description ?? null}, ${point},
        round(ST_Y((${point})::geometry)::numeric, 3)::double precision,
        round(ST_X((${point})::geometry)::numeric, 3)::double precision,
        ${data.emergency ?? false}, ${data.endorsements ?? 0}, ${data.score ?? 0}, ${NOW}, ${NOW}
      )
    `.execute(db);
    return id;
  }
  const ids = (response: { body: { datos: Array<{ id: string }> } }) =>
    response.body.datos.map((item) => item.id);

  beforeAll(async () => {
    ({ app } = await createTestApp(inject('databaseUrl')));
    db = createKysely(inject('databaseUrl'), 2);
  });
  afterEach(() => vi.restoreAllMocks());
  afterAll(async () => {
    await app?.close();
    await db?.destroy();
  });

  it('exige sesión y zona, pero permite buscar desde nivel 0 sin clave de idempotencia', async () => {
    await request(server()).get('/v1/servicios').query(ORIGIN).expect(401);
    const owner = await fixture();
    await sql`UPDATE identidad.usuarios SET zona_id = NULL WHERE id = ${owner.providerId}`.execute(
      db,
    );
    const missing = await search({ token: await signIn(owner.phone) }).expect(403);
    expect(missing.body.codigo).toBe('sin_zona');
    await search({ token: await signIn(NEIGHBORS.dario.phone) }).expect(200);
  });

  it('encuentra el servicio sembrado de Gasfitería al buscar gásfiter', async () => {
    const token = await signIn(NEIGHBORS.beto.phone);
    const response = await search({ token }, { q: 'gásfiter', categoriaId: 'gasfiteria' }).expect(
      200,
    );
    expect(ids(response)).toContain(DEMO_SERVICES[0].id);
  });

  it('filtra por radio y zona aunque otra zona tenga un servicio en el mismo punto', async () => {
    const owner = await fixture();
    const near = await insert(owner);
    const middle = await insert(owner, { offsetMeters: 437 });
    const far = await insert(owner, { offsetMeters: 2500 });
    await insert(await fixture());
    expect(ids(await search(owner, { radioM: 100 }).expect(200))).toEqual([near]);
    expect(ids(await search(owner, { radioM: 500 }).expect(200)).sort()).toEqual(
      [near, middle].sort(),
    );
    expect(ids(await search(owner, { radioM: 20000 }).expect(200)).sort()).toEqual(
      [near, middle, far].sort(),
    );
  });

  it('combina categoría y disponibilidad en emergencia sin convertir false en true', async () => {
    const owner = await fixture();
    const urgent = await insert(owner, { emergency: true });
    const normal = await insert(owner);
    const classes = await insert(owner, { categoryId: 'clases', emergency: true });
    expect(
      ids(await search(owner, { categoriaId: 'gasfiteria', soloEmergencia: true }).expect(200)),
    ).toEqual([urgent]);
    expect(
      ids(
        await search(owner, { categoriaId: 'gasfiteria', soloEmergencia: false }).expect(200),
      ).sort(),
    ).toEqual([urgent, normal].sort());
    expect(ids(await search(owner, { soloEmergencia: true }).expect(200)).sort()).toEqual(
      [urgent, classes].sort(),
    );
    expect(ids(await search(owner, { categoriaId: 'inexistente' }).expect(200))).toEqual([]);
  });

  it('tolera tildes y errores de tipeo y busca en la descripción con configuración spanish', async () => {
    const owner = await fixture();
    const id = await insert(owner, { description: 'Reparaciones de tuberías y calefones' });
    for (const q of ['gásfiter', 'gasfiter', 'gasfitro', 'calefones', 'tuberías']) {
      expect(ids(await search(owner, { q }).expect(200))).toEqual([id]);
    }
    expect(ids(await search(owner, { q: 'zzzzzzzz' }).expect(200))).toEqual([]);
  });

  it('ordena por vistos buenos, luego puntaje y después id con páginas sin repetidos ni saltos', async () => {
    const owner = await fixture();
    const best = await insert(owner, { endorsements: 2, score: 1 });
    const next = await insert(owner, { endorsements: 1, score: 5 });
    const tied = [
      await insert(owner, { endorsements: 1, score: 4.5 }),
      await insert(owner, { endorsements: 1, score: 4.5 }),
    ].sort();
    const last = await insert(owner, { endorsements: 0, score: 5 });
    const expected = [best, next, ...tied, last];
    const collected: string[] = [];
    let cursor: string | null = null;
    for (let page = 0; page < 3; page += 1) {
      const response = await search(owner, { limite: 2, ...(cursor ? { cursor } : {}) }).expect(
        200,
      );
      collected.push(...ids(response));
      cursor = response.body.siguienteCursor;
      if (cursor) {
        const decoded = JSON.parse(Buffer.from(cursor, 'base64url').toString('utf8'));
        expect(Object.keys(decoded).sort()).toEqual(['id', 'p', 'v']);
      }
    }
    expect(cursor).toBeNull();
    expect(collected).toEqual(expected);
    expect(new Set(collected).size).toBe(5);
  });

  it('continúa con el mismo cursor aunque se retire el servicio que cerraba la página', async () => {
    const owner = await fixture();
    const all = [
      await insert(owner),
      await insert(owner),
      await insert(owner),
      await insert(owner),
    ].sort();
    const first = await search(owner, { limite: 2 }).expect(200);
    expect(ids(first)).toEqual(all.slice(0, 2));
    await sql`UPDATE directorio.servicios SET eliminado_en = ${NOW} WHERE id = ${all[1]!}`.execute(
      db,
    );
    const next = await search(owner, { limite: 2, cursor: first.body.siguienteCursor }).expect(200);
    expect(ids(next)).toEqual(all.slice(2));
    expect(next.body.siguienteCursor).toBeNull();
  });

  it('excluye servicios retirados u ocultos y perfiles ocultos, retirados o de otra zona', async () => {
    const owner = await fixture();
    const visible = await insert(owner);
    const removed = await insert(owner);
    const hidden = await insert(owner);
    await sql`UPDATE directorio.servicios SET eliminado_en = ${NOW} WHERE id = ${removed}`.execute(
      db,
    );
    await sql`UPDATE directorio.servicios SET oculto_en = ${NOW} WHERE id = ${hidden}`.execute(db);
    const other = await fixture();
    await insert({ ...owner, providerId: other.providerId });
    expect(ids(await search(owner).expect(200))).toEqual([visible]);
    await sql`UPDATE directorio.proveedores SET oculto_en = ${NOW} WHERE id = ${owner.providerId}`.execute(
      db,
    );
    expect(ids(await search(owner).expect(200))).toEqual([]);
    await sql`UPDATE directorio.proveedores SET oculto_en = NULL, eliminado_en = ${NOW} WHERE id = ${owner.providerId}`.execute(
      db,
    );
    expect(ids(await search(owner).expect(200))).toEqual([]);
  });

  it('devuelve 450 m para 437 m y solo la copia pública de la ubicación', async () => {
    const owner = await fixture();
    await insert(owner, { offsetMeters: 437 });
    const response = await search(owner).expect(200);
    expect(response.body.datos[0].distanciaMetros).toBe(450);
    expect(response.body.datos[0].ubicacion.lat).toBe(
      Number(response.body.datos[0].ubicacion.lat.toFixed(3)),
    );
    expect(response.body.datos[0].ubicacion.lng).toBe(
      Number(response.body.datos[0].ubicacion.lng.toFixed(3)),
    );
    for (const key of [
      'telefono',
      'location',
      'ubicacionPrivada',
      'muestraUbicacionExacta',
      'distancia_m',
    ]) {
      expect(response.body.datos[0]).not.toHaveProperty(key);
    }
    expect(JSON.stringify(response.body)).not.toContain(owner.phone);
  });

  it('buscar no modifica servicios ni crea outbox o idempotencia y el registro HTTP omite el punto', async () => {
    const owner = await fixture();
    const id = await insert(owner);
    const state = async () => {
      const { rows } = await sql<{
        snapshot: unknown;
      }>`SELECT to_jsonb(s) AS snapshot FROM directorio.servicios s WHERE id = ${id}`.execute(db);
      const counters = await sql<{ events: number; keys: number }>`
        SELECT (SELECT count(*)::int FROM compartido.outbox) AS events,
          (SELECT count(*)::int FROM compartido.idempotencia WHERE alcance = ${owner.providerId}) AS keys
      `.execute(db);
      return { rows, counters: counters.rows };
    };
    const before = await state();
    const record = vi.spyOn(app.get(HttpRequestLogger), 'record');
    await search(owner, { lat: -12.0856123, lng: -77.0345123 }).expect(200);
    expect(await state()).toEqual(before);
    expect(record).toHaveBeenCalledWith(
      expect.objectContaining({ ruta: expect.stringMatching(/\/?v1\/servicios$/) }),
    );
    const log = JSON.stringify(record.mock.calls);
    expect(log).not.toContain('-12.0856123');
    expect(log).not.toContain('-77.0345123');
  });

  it('actualiza el tsvector generado cuando cambia el título o la descripción', async () => {
    const owner = await fixture();
    const id = await insert(owner);
    await sql`UPDATE directorio.servicios SET titulo = 'Carpintería fina', descripcion = 'Restauro muebles antiguos' WHERE id = ${id}`.execute(
      db,
    );
    expect(ids(await search(owner, { q: 'muebles' }).expect(200))).toEqual([id]);
    expect(ids(await search(owner, { q: 'gasfiter' }).expect(200))).toEqual([]);
  });

  it('fija el umbral de trigramas solo durante la transacción y no contamina la conexión', async () => {
    const owner = await fixture();
    const id = await insert(owner);
    const isolated = createKysely(inject('databaseUrl'), 1);
    try {
      await sql`SELECT set_config('pg_trgm.word_similarity_threshold', '0.9', false)`.execute(
        isolated,
      );
      const reader = new KyselyServiceSearchReader(isolated as Kysely<DirectoryTables>);
      const result = await reader.search({
        location: ORIGIN,
        zoneId: owner.zoneId,
        radiusMeters: 2000,
        text: 'gasfitro',
        emergencyOnly: false,
        cursor: null,
        limit: 20,
      });
      expect(result.data.map((hit) => hit.service.id)).toEqual([id]);
      const { rows } = await sql<{
        threshold: string;
      }>`SELECT current_setting('pg_trgm.word_similarity_threshold') AS threshold`.execute(
        isolated,
      );
      expect(Number(rows[0]?.threshold)).toBe(0.9);
    } finally {
      await isolated.destroy();
    }
  });

  it('responde 400 ante filtros o cursores inválidos sin reflejar el punto en el problema', async () => {
    const owner = await fixture();
    for (const invalid of [
      { lat: '91' },
      { radioM: 99 },
      { radioM: 20001 },
      { limite: 51 },
      { soloEmergencia: 'no' },
      { q: '  ' },
      { cursor: '!' },
      { categoriaId: 'gasfitería' },
    ]) {
      const response = await search(owner, { ...invalid, lng: -77.0345123 }).expect(400);
      expect(response.body.codigo).toBe('validacion');
      expect(response.body.instance).not.toContain('-77.0345123');
    }
  });
});
