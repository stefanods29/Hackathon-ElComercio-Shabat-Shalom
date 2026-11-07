import type { INestApplication } from '@nestjs/common';
import { type Kysely, sql } from 'kysely';
import request from 'supertest';
import { inject } from 'vitest';
import { NEIGHBORS, PILOT_ZONE } from '../../scripts/seed-data.js';
import type { NearbyPostsResponse } from '../../src/modules/solidaridad/api/schemas.js';
import type { PostStatus, Coordinates } from '../../src/modules/solidaridad/domain/post.js';
import { encodeNearbyCursor } from '../../src/modules/solidaridad/application/nearby-cursor.js';
import { TokenService } from '../../src/shared/auth/token.service.js';
import { createKysely } from '../../src/shared/db/connection.js';
import { newId } from '../../src/shared/domain/ids.js';
import { createTestApp } from '../support/app.js';

describe('Búsqueda por cercanía con PostGIS', () => {
  let app: INestApplication;
  let db: Kysely<unknown>;
  let token: string;
  const zoneId = newId();
  const userId = newId();
  const origin = { lat: -12.086, lng: -77.035 };
  const point = sql`ST_SetSRID(ST_MakePoint(${origin.lng}, ${origin.lat}), 4326)::geography`;
  const search = (query: Record<string, string | number> = {}, access = token) =>
    request(app.getHttpServer())
      .get('/v1/publicaciones')
      .auth(access, { type: 'bearer' })
      .query({ ...origin, ...query });

  async function fixture(
    distance: number,
    options: {
      id?: string;
      status?: PostStatus;
      expiresAt?: Date;
      deleted?: boolean;
      noLocation?: boolean;
      zoneId?: string;
      location?: Coordinates;
    } = {},
  ): Promise<string> {
    const id = options.id ?? newId();
    const location = options.location;
    await sql`
      WITH position AS (SELECT ST_Project(${point}, ${distance}::double precision, 0::double precision)::geometry AS geo),
      approximate AS (SELECT
        ${location?.lat ?? null}::double precision AS explicit_lat,
        ${location?.lng ?? null}::double precision AS explicit_lng,
        round(ST_Y(geo)::numeric, 3)::double precision AS projected_lat,
        round(ST_X(geo)::numeric, 3)::double precision AS projected_lng FROM position),
      coordinates AS (SELECT coalesce(explicit_lat, projected_lat) AS lat, coalesce(explicit_lng, projected_lng) AS lng FROM approximate)
      INSERT INTO solidaridad.publicaciones (id, autor_id, zona_id, tipo, categoria, titulo, lat, lng, ubicacion,
        estado, tomada_por_id, vence_en, eliminado_en)
      SELECT ${id}, ${userId}, ${options.zoneId ?? zoneId}, 'presto', 'agua', 'Presto bidones de agua',
        CASE WHEN ${options.noLocation ?? false} THEN NULL ELSE lat END,
        CASE WHEN ${options.noLocation ?? false} THEN NULL ELSE lng END,
        CASE WHEN ${options.noLocation ?? false} THEN NULL ELSE ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography END,
        ${options.status ?? 'abierta'}, ${options.status === 'en_curso' || options.status === 'resuelta' ? NEIGHBORS.beto.id : null},
        ${options.expiresAt ?? null}, CASE WHEN ${options.deleted ?? false} THEN now() ELSE NULL END
      FROM coordinates
    `.execute(db);
    return id;
  }

  beforeAll(async () => {
    ({ app } = await createTestApp(inject('databaseUrl')));
    db = createKysely(inject('databaseUrl'), 2);
    await sql`INSERT INTO identidad.zonas (id, nombre, distrito, limite)
      SELECT ${zoneId}, 'Zona aislada de prueba', distrito, limite FROM identidad.zonas WHERE id = ${PILOT_ZONE.id}`.execute(
      db,
    );
    await sql`INSERT INTO identidad.usuarios (id, telefono, nombre_visible, zona_id, nivel_confianza)
      VALUES (${userId}, '+51915000001', 'Vecino de prueba', ${zoneId}, 0)`.execute(db);
    ({ token } = await app
      .get(TokenService)
      .issueAccess({ id: userId, zoneId, trustLevel: 0, roles: [] }));
  });

  beforeEach(async () => {
    await sql`DELETE FROM solidaridad.publicaciones WHERE autor_id = ${userId}`.execute(db);
  });
  afterAll(async () => {
    if (db) {
      await sql`DELETE FROM solidaridad.publicaciones WHERE autor_id = ${userId}`.execute(db);
      await sql`DELETE FROM identidad.usuarios WHERE id = ${userId}`.execute(db);
      await sql`DELETE FROM identidad.zonas WHERE id = ${zoneId}`.execute(db);
    }
    await app?.close();
    await db?.destroy();
  });

  it('a 2 km devuelve 500 m y 1,5 km en orden; excluye el favor a 3 km', async () => {
    const near = await fixture(500);
    const middle = await fixture(1500);
    await fixture(3000);
    const response = await search().expect(200);
    const page = response.body as NearbyPostsResponse;
    expect(page.datos.map((post) => post.id)).toEqual([near, middle]);
    expect(page.siguienteCursor).toBeNull();
    expect(page.datos[0]!.distanciaMetros).toBeGreaterThanOrEqual(400);
    expect(page.datos[0]!.distanciaMetros).toBeLessThanOrEqual(600);
    expect(page.datos[1]!.distanciaMetros).toBeGreaterThanOrEqual(1400);
    for (const post of page.datos) {
      expect(post.distanciaMetros % 50).toBe(0);
      expect(post.ubicacion!.lat * 1000).toBeCloseTo(Math.round(post.ubicacion!.lat * 1000), 5);
      expect(post).not.toHaveProperty('distancia');
      expect(post).not.toHaveProperty('ubicacionDeBusqueda');
    }
    const index = await sql<{
      indexdef: string;
    }>`SELECT indexdef FROM pg_indexes WHERE indexname = 'publicaciones_ubicacion_gix'`.execute(db);
    expect(index.rows[0]?.indexdef).toContain('USING gist');
  });

  it('limite=1 recorre ambas páginas y el cursor no filtra una distancia precisa', async () => {
    const near = await fixture(500);
    const middle = await fixture(1500);
    const first = await search({ limite: 1 }).expect(200);
    expect(first.body.datos.map((post: { id: string }) => post.id)).toEqual([near]);
    expect(JSON.parse(Buffer.from(first.body.siguienteCursor, 'base64url').toString())).toEqual({
      d: first.body.datos[0].distanciaMetros,
      id: near,
    });
    const second = await search({ limite: 1, cursor: first.body.siguienteCursor }).expect(200);
    expect(second.body.datos.map((post: { id: string }) => post.id)).toEqual([middle]);
    expect(second.body.siguienteCursor).toBeNull();
  });

  it('no salta filas con la misma distancia redondeada pero distinto orden real', async () => {
    const farther = await fixture(500, { location: { lat: -12.083, lng: -77.031 } });
    const closer = await fixture(500, { location: { lat: -12.086, lng: -77.03 } });
    const first = await search({ limite: 1 }).expect(200);
    expect(first.body.datos[0].id).toBe(closer);
    const second = await search({ limite: 1, cursor: first.body.siguienteCursor }).expect(200);
    expect(second.body.datos[0].id).toBe(farther);
    expect(first.body.datos[0].distanciaMetros).toBe(second.body.datos[0].distanciaMetros);
    expect(second.body.siguienteCursor).toBeNull();
  });

  it('desempata distancias idénticas por UUID sin repetir ni omitir filas', async () => {
    const lowId = newId();
    const highId = newId();
    await fixture(500, { id: highId });
    await fixture(500, { id: lowId });
    const first = await search({ limite: 1 }).expect(200);
    const second = await search({ limite: 1, cursor: first.body.siguienteCursor }).expect(200);
    expect([first.body.datos[0].id, second.body.datos[0].id]).toEqual([lowId, highId]);
    expect(second.body.siguienteCursor).toBeNull();
  });

  it('excluye otros estados, vencidas, eliminadas, sin ubicación y otras zonas', async () => {
    const visible = await fixture(500);
    for (const status of ['en_curso', 'resuelta', 'cancelada'] as const)
      await fixture(600, { status });
    await fixture(600, { expiresAt: new Date(Date.now() - 1000) });
    await fixture(600, { deleted: true });
    await fixture(600, { noLocation: true });
    await fixture(600, { zoneId: PILOT_ZONE.id });
    const response = await search({ radio: 5000 }).expect(200);
    expect(response.body.datos.map((post: { id: string }) => post.id)).toEqual([visible]);
  });

  it('el cursor sigue recorriendo si su ancla se cancela o elimina lógicamente', async () => {
    const firstId = await fixture(500);
    const secondId = await fixture(1500);
    const first = await search({ limite: 1 }).expect(200);
    await sql`UPDATE solidaridad.publicaciones SET estado = 'cancelada', eliminado_en = now() WHERE id = ${firstId}`.execute(
      db,
    );
    const second = await search({ limite: 1, cursor: first.body.siguienteCursor }).expect(200);
    expect(second.body.datos[0].id).toBe(secondId);
  });

  it('una búsqueda sin coincidencias devuelve datos vacíos y cursor nulo', async () => {
    await search().expect(200, { datos: [], siguienteCursor: null });
    await fixture(500);
    await search({ radio: 100 }).expect(200, { datos: [], siguienteCursor: null });
  });

  it('rechaza cursores malformados, desconocidos, ajenos y con distancia alterada', async () => {
    const id = await fixture(500);
    const foreign = await fixture(500, { zoneId: PILOT_ZONE.id });
    for (const cursor of [
      '!',
      'a'.repeat(513),
      encodeNearbyCursor({ d: 0, id: newId() }),
      encodeNearbyCursor({ d: 0, id: foreign }),
      encodeNearbyCursor({ d: 0, id }),
    ]) {
      const response = await search({ cursor }).expect(400);
      expect(response.body.codigo).toBe('validacion');
    }
  });

  it('valida coordenadas y límites y requiere autenticación y zona', async () => {
    const invalidQueries: Array<Record<string, string | number>> = [
      { lat: '' },
      { lat: 91 },
      { lng: -181 },
      { lat: 'NaN' },
      { radio: 99 },
      { radio: 5001 },
      { radio: 100.5 },
      { limite: 0 },
      { limite: 51 },
      { limite: 1.5 },
    ];
    for (const query of invalidQueries) {
      await search(query).expect(400);
    }
    await request(app.getHttpServer())
      .get('/v1/publicaciones')
      .auth(token, { type: 'bearer' })
      .query({ lat: origin.lat })
      .expect(400);
    await request(app.getHttpServer()).get('/v1/publicaciones').query(origin).expect(401);
    const unassigned = await app
      .get(TokenService)
      .issueAccess({ id: userId, zoneId: null, trustLevel: 0, roles: [] });
    expect((await search({}, unassigned.token).expect(403)).body.codigo).toBe('sin_zona');
  });
});
