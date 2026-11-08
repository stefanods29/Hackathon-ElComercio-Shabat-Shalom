import type { INestApplication } from '@nestjs/common';
import { type Kysely, sql } from 'kysely';
import request from 'supertest';
import { inject } from 'vitest';
import { NEIGHBORS, PILOT_ZONE } from '../../scripts/seed-data.js';
import { TokenService } from '../../src/shared/auth/token.service.js';
import { createKysely } from '../../src/shared/db/connection.js';
import { newId } from '../../src/shared/domain/ids.js';
import { createTestApp } from '../support/app.js';

describe('Telemetría de sincronización por HTTP y PostgreSQL', () => {
  let app: INestApplication;
  let db: Kysely<unknown>;
  let admin: string;
  let neighbor: string;
  const server = () => app.getHttpServer();
  /** A version unique to this run, so the rows of other suites never mix in. */
  const version = `0.0.1+${newId().replaceAll('-', '').slice(0, 12)}`;
  const code = `prueba_${newId().replaceAll('-', '').slice(0, 12)}`;
  const report = (changes: Record<string, unknown> = {}) => ({
    versionApp: version,
    sistema: 'android',
    periodoInicio: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString(),
    periodoFin: new Date().toISOString(),
    colaPendientes: 2,
    enviosConfirmados: 3,
    tiempoHastaEnviadoP50Segundos: 20,
    tiempoHastaEnviadoP95Segundos: 90,
    rechazosPermanentes: { [code]: 2 },
    segundosDesdeUltimaSincronizacion: 30,
    erroresDeConexion: 1,
    ...changes,
  });
  const send = (body: object, key = newId(), token: string | null = neighbor) => {
    const call = request(server())
      .post('/v1/telemetria/sincronizacion')
      .set('Idempotency-Key', key)
      .send(body);
    return token ? call.auth(token, { type: 'bearer' }) : call;
  };
  const storedRows = async () =>
    (
      await sql<{ total: number }>`
        SELECT count(*)::int AS total FROM compartido.telemetria_sincronizacion
        WHERE version_app = ${version}
      `.execute(db)
    ).rows[0]!.total;
  const metrics = (token: string) =>
    request(server()).get('/v1/operacion/metricas').auth(token, { type: 'bearer' });

  beforeAll(async () => {
    ({ app } = await createTestApp(inject('databaseUrl')));
    await app.listen(0, '127.0.0.1');
    db = createKysely(inject('databaseUrl'), 2);
    const tokens = app.get(TokenService);
    ({ token: admin } = await tokens.issueAccess({
      id: NEIGHBORS.carla.id,
      zoneId: PILOT_ZONE.id,
      trustLevel: 3,
      roles: ['administrador'],
    }));
    ({ token: neighbor } = await tokens.issueAccess({
      id: NEIGHBORS.ana.id,
      zoneId: PILOT_ZONE.id,
      trustLevel: 2,
      roles: [],
    }));
  });
  afterAll(async () => {
    await app?.close();
    await db?.destroy();
  });

  it('guarda los contadores con 202 y sin identidad; un reintento no duplica la fila', async () => {
    const key = newId();
    const body = report();
    const first = await send(body, key).expect(202);
    expect(first.body).toEqual({ recibidoEl: expect.stringMatching(/^\d{4}-\d{2}-\d{2}$/) });
    // A replay answers 200 with the stored body, like every idempotent route.
    const retry = await send(body, key).expect(200);
    expect(retry.body).toEqual(first.body);
    expect(retry.headers['idempotent-replayed']).toBe('true');
    expect(await storedRows()).toBe(1);

    const { rows } = await sql<Record<string, unknown>>`
      SELECT * FROM compartido.telemetria_sincronizacion WHERE version_app = ${version}
    `.execute(db);
    expect(JSON.stringify(rows)).not.toContain(NEIGHBORS.ana.id);
    expect(rows[0]).toMatchObject({
      sistema: 'android',
      cola_pendientes: 2,
      envios_confirmados: 3,
      tiempo_hasta_enviado_p50_segundos: 20,
      tiempo_hasta_enviado_p95_segundos: 90,
      rechazos_permanentes: { [code]: 2 },
      errores_de_conexion: 1,
    });
  });

  it('la tabla no tiene columnas de vecino, dispositivo, hora exacta ni ubicación', async () => {
    const { rows } = await sql<{ column_name: string }>`
      SELECT column_name FROM information_schema.columns
      WHERE table_schema = 'compartido' AND table_name = 'telemetria_sincronizacion'
      ORDER BY ordinal_position
    `.execute(db);
    expect(rows.map((row) => row.column_name)).toEqual([
      'id',
      'recibido_el',
      'version_app',
      'sistema',
      'duracion_periodo_minutos',
      'cola_pendientes',
      'envios_confirmados',
      'tiempo_hasta_enviado_p50_segundos',
      'tiempo_hasta_enviado_p95_segundos',
      'rechazos_permanentes',
      'segundos_desde_ultima_sincronizacion',
      'errores_de_conexion',
    ]);
  });

  it('responde 400 validacion con un campo no previsto y no guarda nada', async () => {
    const before = await storedRows();
    const response = await send({ ...report(), telefono: '+51900000009' }).expect(400);
    expect(response.body.codigo).toBe('validacion');
    expect(await storedRows()).toBe(before);
  });

  it('responde 401 sin sesión', async () => {
    const before = await storedRows();
    await send(report(), newId(), null).expect(401);
    expect(await storedRows()).toBe(before);
  });

  it('el administrador ve el resumen de 7 días y un vecino recibe 403', async () => {
    const before = (await metrics(admin).expect(200)).body.sincronizacion;
    await send(report({ tiempoHastaEnviadoP95Segundos: 120 })).expect(202);
    const after = (await metrics(admin).expect(200)).body.sincronizacion;
    expect(after.reportes).toBe(before.reportes + 1);
    expect(after.enviosConfirmados).toBe(before.enviosConfirmados + 3);
    expect(after.rechazosPermanentes[code]).toBe((before.rechazosPermanentes[code] ?? 0) + 2);
    expect(after.tiempoHastaEnviadoP95Segundos).toEqual(expect.any(Number));
    expect(after.desde).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    expect(JSON.stringify(after)).not.toContain(NEIGHBORS.ana.id);
    const forbidden = await metrics(neighbor).expect(403);
    expect(forbidden.body.codigo).toBe('rol_requerido');
  });
});
