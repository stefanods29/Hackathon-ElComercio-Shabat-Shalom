import type { INestApplication } from '@nestjs/common';
import { type Kysely, sql } from 'kysely';
import request from 'supertest';
import { inject } from 'vitest';
import { DEMO_SERVICES, NEIGHBORS, NEIGHBOR_ZONE, PILOT_ZONE } from '../../scripts/seed-data.js';
import { OTP_PROVIDER } from '../../src/modules/identidad/application/ports.js';
import type { FakeOtpProvider } from '../../src/modules/identidad/infrastructure/fake-otp.provider.js';
import { TokenService } from '../../src/shared/auth/token.service.js';
import { createKysely } from '../../src/shared/db/connection.js';
import { CLOCK } from '../../src/shared/domain/clock.js';
import { newId } from '../../src/shared/domain/ids.js';
import {
  IDEMPOTENCY_STORE,
  type IdempotencyStore,
} from '../../src/shared/idempotency/idempotency-store.js';
import type { OutboxJob } from '../../src/shared/outbox/outbox-relay.js';
import { PersonalDataRegistry } from '../../src/shared/privacy/personal-data.registry.js';
import { JobHandlerRegistry } from '../../src/shared/queues/job-handler.registry.js';
import { InMemoryJobQueue } from '../../src/shared/queues/job-queue.memory.js';
import { createTestApp } from '../support/app.js';

const NOW = new Date('2026-11-08T02:00:00Z'); // 7 de noviembre en Lima.
const OLD_ZONE_DATE = new Date('2026-10-09T02:00:00Z');
const PURPOSE = 'confirmacion_por_presencia';
const ZONE_EVENT = 'identidad.zona_cambiada';
const RESIDENCE_EVENT = 'identidad.residencia_confirmada';
const ERASURE_EVENT = 'identidad.cuenta_borrada';
const SERVICE = DEMO_SERVICES[0].id;

interface NeighborOptions {
  level?: number;
  moderator?: boolean;
  zoneId?: string;
  chosenAt?: Date;
}

describe('Residencia y derechos sobre datos personales con PostgreSQL', () => {
  let app: INestApplication;
  let db: Kysely<unknown>;
  let queue: InMemoryJobQueue;
  let tokenService: TokenService;
  let now = NOW;
  let sequence = 0;
  const clock = { now: () => now };
  const server = () => app.getHttpServer();
  const write = (
    method: 'post' | 'put' | 'patch' | 'delete',
    path: string,
    token: string,
    key = newId(),
  ) => request(server())[method](path).auth(token, { type: 'bearer' }).set('Idempotency-Key', key);
  const get = (path: string, token: string) =>
    request(server()).get(path).auth(token, { type: 'bearer' });
  const choose = (token: string, zoneId: string) =>
    write('put', '/v1/yo/zona', token).send({ zonaId: zoneId });
  const decide = (token: string, accepted: boolean, version = 1, purpose: string = PURPOSE) =>
    write('post', '/v1/yo/consentimientos', token).send({
      finalidad: purpose,
      version,
      aceptado: accepted,
    });
  const presence = (token: string, day: string, inside = true) =>
    write('post', '/v1/yo/residencia/presencia', token).send({
      fecha: day,
      dentroDeLaZona: inside,
    });

  async function devSignIn(phone: string): Promise<string> {
    const response = await request(server())
      .post('/v1/dev/sesiones')
      .send({ telefono: phone })
      .expect(201);
    return response.body.tokenDeAcceso as string;
  }

  async function otpSignIn(
    phone: string,
    device?: string,
  ): Promise<{ token: string; refresh: string }> {
    const otp = app.get<FakeOtpProvider>(OTP_PROVIDER);
    await request(server()).post('/v1/auth/otp').send({ telefono: phone }).expect(202);
    const response = await request(server())
      .post('/v1/auth/otp/verificar')
      .send({ telefono: phone, codigo: otp.lastCodeFor(phone), dispositivo: device })
      .expect(200);
    return {
      token: response.body.tokenDeAcceso as string,
      refresh: response.body.refreshToken as string,
    };
  }

  async function neighbor(options: NeighborOptions = {}) {
    const id = newId();
    const phone = `+5191840${String(++sequence).padStart(4, '0')}`;
    await sql`
      INSERT INTO identidad.usuarios (id, telefono, nombre_visible, zona_id, zona_elegida_en,
        nivel_confianza, roles, creado_en, actualizado_en)
      VALUES (${id}, ${phone}, 'Vecino de prueba de privacidad', ${options.zoneId ?? PILOT_ZONE.id},
        ${options.chosenAt ?? OLD_ZONE_DATE}, ${options.level ?? 0},
        ${options.moderator ? ['moderador'] : []}::text[], ${OLD_ZONE_DATE}, ${OLD_ZONE_DATE})
    `.execute(db);
    return { id, phone, token: await devSignIn(phone) };
  }

  async function events(type: string, aggregateId: string): Promise<OutboxJob[]> {
    const { rows } = await sql<{
      id: string;
      modulo: string;
      agregado_id: string;
      carga: unknown;
      ocurrido_en: Date;
    }>`
      SELECT id, modulo, agregado_id, carga, ocurrido_en FROM compartido.outbox
      WHERE tipo = ${type} AND agregado_id = ${aggregateId} ORDER BY ocurrido_en, id
    `.execute(db);
    return rows.map((row) => ({
      eventoId: row.id,
      modulo: row.modulo,
      agregadoId: row.agregado_id,
      carga: row.carga,
      ocurridoEn: row.ocurrido_en.toISOString(),
    }));
  }

  async function presenceRows(userId: string) {
    const { rows } = await sql<{ fecha: string; dentro_de_la_zona: boolean }>`
      SELECT fecha::text, dentro_de_la_zona FROM identidad.presencias WHERE usuario_id = ${userId} ORDER BY fecha
    `.execute(db);
    return rows;
  }

  async function tablesWithPersonalData(phone: string, name: string): Promise<string[]> {
    const { rows: tables } = await sql<{ schema_name: string; table_name: string }>`
      SELECT n.nspname AS schema_name, c.relname AS table_name
      FROM pg_class AS c JOIN pg_namespace AS n ON n.oid = c.relnamespace
      WHERE c.relkind IN ('r', 'p') AND n.nspname NOT IN ('pg_catalog', 'information_schema')
        AND n.nspname !~ '^pg_' ORDER BY 1, 2
    `.execute(db);
    const matches: string[] = [];
    for (const { schema_name: schema, table_name: table } of tables) {
      const { rows } = await sql<{ found: boolean }>`
        SELECT EXISTS (SELECT 1 FROM ${sql.id(schema, table)} AS r
          WHERE strpos(to_jsonb(r)::text, ${phone}) > 0
            OR strpos(lower(to_jsonb(r)::text), lower(${name})) > 0) AS found
      `.execute(db);
      if (rows[0]?.found) matches.push(`${schema}.${table}`);
    }
    return matches;
  }

  beforeAll(async () => {
    ({ app } = await createTestApp(
      inject('databaseUrl'),
      { OTP_MAX_REQUESTS_PER_IP: '1000', OTP_MAX_REQUESTS_PER_PHONE: '10' },
      (builder) => builder.overrideProvider(CLOCK).useValue(clock),
    ));
    await app.listen(0, '127.0.0.1');
    db = createKysely(inject('databaseUrl'), 4);
    tokenService = app.get(TokenService);
    queue = new InMemoryJobQueue(clock);
    await app.get(JobHandlerRegistry).startAll(queue);
  });

  beforeEach(() => {
    now = NOW;
  });

  afterAll(async () => {
    await app?.close();
    await db?.destroy();
  });

  it('conserva el nivel al elegir la misma zona y devuelve disponibleDesde si el cambio es temprano', async () => {
    const chosenAt = new Date('2026-10-29T02:00:00Z');
    const user = await neighbor({ level: 2, chosenAt });
    const same = await choose(user.token, PILOT_ZONE.id).expect(200);
    expect(same.body.usuario).toMatchObject({ nivel: 2, zonaId: PILOT_ZONE.id });
    const early = await choose(user.token, NEIGHBOR_ZONE.id).expect(409);
    expect(early.body).toMatchObject({
      codigo: 'cambio_de_zona_muy_pronto',
      disponibleDesde: '2026-11-28T02:00:00.000Z',
    });
    expect(await events(ZONE_EVENT, user.id)).toEqual([]);
  });

  it('cambia de zona en el límite, baja al nivel 0 y retira los servicios de la zona anterior', async () => {
    const user = await neighbor({ level: 2 });
    await write('put', '/v1/yo/proveedor', user.token)
      .send({ nombrePublico: 'Proveedor en mudanza' })
      .expect(200);
    const serviceId = newId();
    await write('post', '/v1/servicios', user.token)
      .send({
        id: serviceId,
        categoriaId: 'gasfiteria',
        titulo: 'Servicio de la zona anterior',
        ubicacion: { lat: -12.0856, lng: -77.0345 },
      })
      .expect(201);
    const updated = await choose(user.token, NEIGHBOR_ZONE.id).expect(200);
    expect(updated.body.usuario).toMatchObject({ nivel: 0, zonaId: NEIGHBOR_ZONE.id });
    await expect(tokenService.verifyAccess(updated.body.tokenDeAcceso)).resolves.toMatchObject({
      trustLevel: 0,
      zoneId: NEIGHBOR_ZONE.id,
    });
    const oldToken = await write('put', '/v1/yo/proveedor', user.token)
      .send({ nombrePublico: 'Intento anterior' })
      .expect(403);
    expect(oldToken.body.codigo).toBe('nivel_de_confianza_insuficiente');
    const [event, extra] = await events(ZONE_EVENT, user.id);
    expect(extra).toBeUndefined();
    expect(event?.carga).toEqual({ zonaAnteriorId: PILOT_ZONE.id, zonaId: NEIGHBOR_ZONE.id });
    await queue.enqueue(ZONE_EVENT, event);
    await queue.drain();
    const { rows } = await sql<{ eliminado_en: Date | null }>`
      SELECT eliminado_en FROM directorio.servicios WHERE id = ${serviceId}
    `.execute(db);
    expect(rows[0]?.eliminado_en).toBeInstanceOf(Date);
  });

  it('sin consentimiento vigente no trata la presencia ni guarda un evento', async () => {
    const user = await neighbor();
    const missing = await presence(user.token, '2026-11-07').expect(403);
    expect(missing.body.codigo).toBe('consentimiento_requerido');
    await decide(user.token, true, 1, 'uso_del_servicio').expect(200);
    await decide(user.token, false).expect(200);
    const rejected = await presence(user.token, '2026-11-07').expect(403);
    expect(rejected.body.codigo).toBe('consentimiento_requerido');
    expect(await presenceRows(user.id)).toEqual([]);
    expect(await events(RESIDENCE_EVENT, user.id)).toEqual([]);
  });

  it('promueve por tres días distintos dentro de 14 y rechaza coordenadas y fechas fuera de la ventana', async () => {
    const user = await neighbor();
    await decide(user.token, true).expect(200);
    await write('post', '/v1/yo/residencia/presencia', user.token)
      .send({ fecha: '2026-11-07', dentroDeLaZona: true, lat: -12.08 })
      .expect(400);
    const tooOld = await presence(user.token, '2026-10-24').expect(422);
    expect(tooOld.body.codigo).toBe('fecha_de_presencia_invalida');
    await presence(user.token, '2026-11-08').expect(422);
    expect((await presence(user.token, '2026-10-25').expect(200)).body.nivel).toBe(0);
    expect((await presence(user.token, '2026-10-25').expect(200)).body.nivel).toBe(0);
    expect((await presence(user.token, '2026-10-26', false).expect(200)).body.nivel).toBe(0);
    expect((await presence(user.token, '2026-10-26').expect(200)).body.nivel).toBe(0);
    expect((await presence(user.token, '2026-11-06').expect(200)).body.nivel).toBe(0);
    expect((await presence(user.token, '2026-11-07').expect(200)).body.nivel).toBe(1);
    expect(await presenceRows(user.id)).toHaveLength(4);
    const records = await events(RESIDENCE_EVENT, user.id);
    expect(records).toHaveLength(1);
    expect(records[0]?.carga).toEqual({ zonaId: PILOT_ZONE.id, nivel: 1, metodo: 'presencia' });
    await expect(tokenService.verifyAccess(await devSignIn(user.phone))).resolves.toMatchObject({
      trustLevel: 1,
    });
  });

  it('el trabajo diario borra presencias de 30 días y conserva las más recientes', async () => {
    const user = await neighbor();
    await sql`
      INSERT INTO identidad.presencias (usuario_id, fecha, dentro_de_la_zona)
      VALUES (${user.id}, '2026-10-08', true), (${user.id}, '2026-10-09', true)
    `.execute(db);
    await queue.enqueue('identidad.limpiar_presencias', {});
    await queue.drain();
    expect(await presenceRows(user.id)).toEqual([{ fecha: '2026-10-09', dentro_de_la_zona: true }]);
  });

  it('audita la confirmación manual de nivel 1 y permite al moderador iniciar el nivel 2', async () => {
    const user = await neighbor();
    const moderator = await neighbor({ moderator: true });
    const path = `/v1/vecinos/${user.id}/residencia`;
    const reason = 'validado por la junta vecinal';
    const forbidden = await write('post', path, user.token).send({ motivo: reason }).expect(403);
    expect(forbidden.body.codigo).toBe('rol_requerido');
    const confirmed = await write('post', path, moderator.token)
      .send({ motivo: reason })
      .expect(200);
    expect(confirmed.body).toEqual({ nivel: 1 });
    const { rows } = await sql`
      SELECT moderador_id, motivo, nivel, creada_en FROM identidad.confirmaciones WHERE vecino_id = ${user.id}
    `.execute(db);
    expect(rows).toEqual([
      { moderador_id: moderator.id, motivo: reason, nivel: 1, creada_en: now },
    ]);
    const bootstrap = await write('post', path, moderator.token)
      .send({ motivo: reason, nivel: 2 })
      .expect(200);
    expect(bootstrap.body).toEqual({ nivel: 2 });
    expect((await events(RESIDENCE_EVENT, user.id)).map((event) => event.carga)).toEqual([
      { zonaId: PILOT_ZONE.id, nivel: 1, metodo: 'manual' },
      { zonaId: PILOT_ZONE.id, nivel: 2, metodo: 'manual' },
    ]);
  });

  it('cuenta dos avales válidos y distintos y rechaza autoavales, otra zona o nivel insuficiente', async () => {
    const user = await neighbor({ level: 1 });
    const first = await devSignIn(NEIGHBORS.ana.phone);
    const second = await neighbor({ level: 2 });
    const outside = await neighbor({ level: 2, zoneId: NEIGHBOR_ZONE.id });
    const path = `/v1/vecinos/${user.id}/aval`;
    const self = await write('post', `/v1/vecinos/${second.id}/aval`, second.token).expect(403);
    expect(self.body.codigo).toBe('no_puedes_avalarte');
    const low = await write('post', `/v1/vecinos/${second.id}/aval`, user.token).expect(403);
    expect(low.body.codigo).toBe('nivel_de_confianza_insuficiente');
    const foreign = await write('post', path, outside.token).expect(403);
    expect(foreign.body.codigo).toBe('fuera_de_tu_zona');
    const key = newId();
    expect((await write('post', path, first, key).expect(200)).body).toEqual({ nivel: 1 });
    const replay = await write('post', path, first, key).expect(200);
    expect(replay.headers['idempotent-replayed']).toBe('true');
    expect((await write('post', path, first).expect(200)).body).toEqual({ nivel: 1 });
    expect((await write('post', path, second.token).expect(200)).body).toEqual({ nivel: 2 });
    expect((await events(RESIDENCE_EVENT, user.id)).map((event) => event.carga)).toEqual([
      { zonaId: PILOT_ZONE.id, nivel: 2, metodo: 'avales' },
    ]);
  });

  it('devuelve finalidades y versiones, registra oposición y conserva el nivel confirmado', async () => {
    const user = await neighbor({ level: 1 });
    const initial = await get('/v1/yo/consentimientos', user.token).expect(200);
    expect(initial.body).toEqual([
      { finalidad: 'uso_del_servicio', versionVigente: 1, obligatoria: true, decision: null },
      { finalidad: PURPOSE, versionVigente: 1, obligatoria: false, decision: null },
    ]);
    const obsolete = await decide(user.token, true, 2).expect(409);
    expect(obsolete.body).toMatchObject({
      codigo: 'version_de_consentimiento_desactualizada',
      versionVigente: 1,
    });
    await decide(user.token, true).expect(200);
    await presence(user.token, '2026-11-07').expect(200);
    await decide(user.token, false).expect(200);
    const stopped = await presence(user.token, '2026-11-07').expect(403);
    expect(stopped.body.codigo).toBe('consentimiento_requerido');
    const current = await get('/v1/yo/consentimientos', user.token).expect(200);
    expect(current.body[1].decision).toEqual({
      aceptado: false,
      version: 1,
      decididoEn: now.toISOString(),
    });
    expect(await presenceRows(user.id)).toEqual([]);
    await expect(tokenService.verifyAccess(await devSignIn(user.phone))).resolves.toMatchObject({
      trustLevel: 1,
    });
  });

  it('rectifica el nombre y exporta los datos propios de cada módulo sin credenciales', async () => {
    const user = await neighbor({ level: 2 });
    const session = await otpSignIn(user.phone, 'Celular para exportación');
    const name = 'Vecina con nombre rectificado';
    const key = newId();
    const update = () => write('patch', '/v1/yo', session.token, key).send({ nombreVisible: name });
    expect((await update().expect(200)).body).toEqual({ nombreVisible: name });
    expect((await update().expect(200)).headers['idempotent-replayed']).toBe('true');
    await decide(session.token, true, 1, 'uso_del_servicio').expect(200);
    await write('put', '/v1/yo/proveedor', session.token)
      .send({ nombrePublico: 'Proveedor de exportación' })
      .expect(200);
    const serviceId = newId();
    await write('post', '/v1/servicios', session.token)
      .send({
        id: serviceId,
        categoriaId: 'gasfiteria',
        titulo: 'Servicio que exporto',
        ubicacion: { lat: -12.085678, lng: -77.034567 },
      })
      .expect(201);
    const postId = newId();
    await write('post', '/v1/publicaciones', session.token)
      .send({
        id: postId,
        tipo: 'presto',
        categoria: 'herramientas',
        titulo: 'Préstamo que exporto',
      })
      .expect(201);
    const reviewId = newId();
    await write('post', '/v1/resenas', session.token)
      .send({
        id: reviewId,
        servicioId: SERVICE,
        calificacion: 5,
        comentario: 'Reseña que exporto',
      })
      .expect(201);
    await write('post', `/v1/servicios/${SERVICE}/visto-bueno`, session.token).expect(200);

    const response = await get('/v1/yo/datos', session.token).expect(200);
    expect(response.headers['cache-control']).toBe('no-store');
    expect(response.body).toMatchObject({
      generadoEn: now.toISOString(),
      modulos: {
        identidad: {
          perfil: { id: user.id, telefono: user.phone, nombreVisible: name },
          zona: { id: PILOT_ZONE.id },
          consentimientos: [{ finalidad: 'uso_del_servicio', version: 1, aceptado: true }],
          sesiones: [{ dispositivo: 'Celular para exportación' }],
        },
        solidaridad: { publicaciones: [{ id: postId }] },
        directorio: {
          servicios: [{ id: serviceId, lat_privada: -12.085678, lng_privada: -77.034567 }],
        },
        reputacion: { resenas: [{ id: reviewId }], vistosBuenos: [{ servicio_id: SERVICE }] },
        moderacion: { denuncias: [] },
      },
    });
    expect(response.text).not.toContain(session.refresh);
    expect(response.text).not.toContain('refresh_hash');
    expect(response.text).not.toContain(NEIGHBORS.ana.phone);
    await request(server()).get('/v1/yo/datos').expect(401);
  });

  it('revoca todas las sesiones al devolver 202 y tras el trabajo no quedan teléfono ni nombre en ninguna tabla', async () => {
    const user = await neighbor({ level: 2 });
    const name = 'Rastro De Borrado Lote Cuatro';
    const one = await otpSignIn(user.phone, name);
    const two = await otpSignIn(user.phone, 'Otro celular');
    await write('patch', '/v1/yo', one.token).send({ nombreVisible: name }).expect(200);
    await write('put', '/v1/yo/proveedor', one.token)
      .send({ nombrePublico: name, descripcion: user.phone })
      .expect(200);
    const serviceId = newId();
    await write('post', '/v1/servicios', one.token)
      .send({
        id: serviceId,
        categoriaId: 'gasfiteria',
        titulo: name,
        descripcion: user.phone,
        ubicacion: { lat: -12.085678, lng: -77.034567 },
        atributos: { referencia: name },
      })
      .expect(201);
    const postId = newId();
    await write('post', '/v1/publicaciones', one.token)
      .send({
        id: postId,
        tipo: 'presto',
        categoria: 'herramientas',
        titulo: name,
        descripcion: user.phone,
      })
      .expect(201);
    const helper = await devSignIn(NEIGHBORS.ana.phone);
    const takeKey = newId();
    const take = () =>
      write('post', `/v1/publicaciones/${postId}/tomar`, helper, takeKey).send({ versionVista: 1 });
    expect((await take().expect(200)).body).toMatchObject({ autorId: user.id, titulo: name });
    const reviewId = newId();
    await write('post', '/v1/resenas', one.token)
      .send({
        id: reviewId,
        servicioId: SERVICE,
        calificacion: 4,
        comentario: `${name} ${user.phone}`,
      })
      .expect(201);
    await sql`UPDATE reputacion.resenas SET estado = 'publicada', publicada_en = ${now} WHERE id = ${reviewId}`.execute(
      db,
    );
    await write('post', `/v1/servicios/${SERVICE}/visto-bueno`, one.token).expect(200);
    await write('post', '/v1/dispositivos', one.token)
      .send({ token: `dispositivo-${user.phone}`, plataforma: 'android' })
      .expect(200);
    await decide(one.token, true).expect(200);
    await presence(one.token, '2026-11-07').expect(200);

    expect(await tablesWithPersonalData(user.phone, name)).toEqual(
      expect.arrayContaining([
        'compartido.idempotencia',
        'directorio.proveedores',
        'directorio.servicios',
        'identidad.codigos_otp',
        'identidad.sesiones',
        'identidad.usuarios',
        'notificaciones.dispositivos',
        'reputacion.resenas',
        'solidaridad.publicaciones',
      ]),
    );

    await write('delete', '/v1/yo', one.token).expect(202);
    for (const session of [one, two]) {
      expect((await get('/v1/yo/datos', session.token).expect(401)).body.codigo).toBe(
        'sesion_revocada',
      );
      await get('/v1/sync/credenciales', session.token).expect(401);
      await request(server())
        .post('/v1/auth/refrescar')
        .send({ refreshToken: session.refresh })
        .expect(401);
    }
    await get('/v1/yo/datos', user.token).expect(401);

    const [event, extra] = await events(ERASURE_EVENT, user.id);
    expect(extra).toBeUndefined();
    expect(event?.carga).toEqual({});
    const lateFailure = new Error('fallo temporal de un participante');
    let shouldFail = true;
    app.get(PersonalDataRegistry).register('prueba', {
      read: async () => ({}),
      erase: async (_tx, account) => {
        if (account.userId === user.id && shouldFail) throw lateFailure;
      },
    });
    await queue.enqueue(ERASURE_EVENT, event);
    await expect(queue.drain()).rejects.toBe(lateFailure);
    expect(await tablesWithPersonalData(user.phone, name)).toContain('identidad.usuarios');

    shouldFail = false;
    for (let delivery = 0; delivery < 2; delivery++) {
      await queue.enqueue(ERASURE_EVENT, event);
      await queue.drain();
    }
    // A third-party request may finish serializing a reply after the worker already ran.
    const cache = app.get<IdempotencyStore>(IDEMPOTENCY_STORE);
    const lateKey = newId();
    expect(
      await cache.reserve(
        {
          scope: NEIGHBORS.ana.id,
          key: lateKey,
          method: 'POST',
          path: `/v1/publicaciones/${postId}/tomar`,
          fingerprint: '0'.repeat(64),
        },
        now,
      ),
    ).toEqual({ kind: 'new' });
    await cache.complete(NEIGHBORS.ana.id, lateKey, 200, { autorId: user.id, titulo: name });
    expect(
      (
        await sql`
      SELECT 1 FROM compartido.idempotencia WHERE alcance = ${NEIGHBORS.ana.id} AND clave = ${lateKey}
    `.execute(db)
      ).rows,
    ).toEqual([]);
    expect(await tablesWithPersonalData(user.phone, name)).toEqual([]);
    await take().expect(404); // No se devuelve la copia con datos del autor al otro vecino.
    expect(
      (
        await sql`
      SELECT comentario, calificacion FROM reputacion.resenas WHERE id = ${reviewId}
    `.execute(db)
      ).rows,
    ).toEqual([{ comentario: null, calificacion: 4 }]);
    expect(
      (
        await sql`
      SELECT 1 FROM reputacion.vistos_buenos WHERE vecino_id = ${user.id}
    `.execute(db)
      ).rows,
    ).toEqual([]);
  });
});
