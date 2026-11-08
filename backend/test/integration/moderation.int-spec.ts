import type { INestApplication } from '@nestjs/common';
import { type Kysely, sql } from 'kysely';
import request from 'supertest';
import { inject } from 'vitest';
import { DEMO_SERVICES, NEIGHBORS, PILOT_ZONE } from '../../scripts/seed-data.js';
import type { Role } from '../../src/shared/auth/actor.js';
import { createKysely } from '../../src/shared/db/connection.js';
import { CLOCK } from '../../src/shared/domain/clock.js';
import { newId } from '../../src/shared/domain/ids.js';
import {
  CONTENT_APPROVED,
  CONTENT_HIDDEN,
  CONTENT_RESTORED,
} from '../../src/shared/moderation/content-moderation.js';
import type { OutboxJob } from '../../src/shared/outbox/outbox-relay.js';
import { JobHandlerRegistry } from '../../src/shared/queues/job-handler.registry.js';
import { InMemoryJobQueue } from '../../src/shared/queues/job-queue.memory.js';
import {
  IMAGE_MODERATION,
  IS_SUSPENDED,
  type ImageModeration,
  type IsSuspended,
} from '../../src/modules/moderacion/index.js';
import { REVIEW_PHOTO_READER } from '../../src/modules/reputacion/index.js';
import { InMemoryReviewPhotoReader } from '../../src/modules/reputacion/infrastructure/review-photo.reader.memory.js';
import { createTestApp } from '../support/app.js';

const NOW = new Date('2026-11-09T15:00:00Z');
const LOCATION = { lat: -12.085678, lng: -77.034567 };
const REPORT_EVENT = 'moderacion.denuncia_registrada';
const REVIEW_CREATED = 'reputacion.resena_creada';
const REVIEW_PUBLISHED = 'reputacion.resena_publicada';
const RECALCULATE = 'reputacion.recalculo_solicitado';
const AGGREGATES = 'reputacion.agregados_recalculados';
const DAY = 86_400_000;

describe('Denuncias y moderación con PostgreSQL', () => {
  let app: INestApplication;
  let db: Kysely<unknown>;
  let queue: InMemoryJobQueue;
  let now = NOW;
  let sequence = 0;
  const clock = { now: () => now };
  const photos = new InMemoryReviewPhotoReader();
  const imageFilter: ImageModeration = { inspect: async () => 'limpia' };
  const server = () => app.getHttpServer();
  const get = (path: string, token: string) =>
    request(server()).get(path).auth(token, { type: 'bearer' });
  const write = (method: 'post' | 'put' | 'delete', path: string, token: string, key = newId()) =>
    request(server())[method](path).auth(token, { type: 'bearer' }).set('Idempotency-Key', key);
  const report = (
    token: string,
    type: string,
    id: string,
    reason = 'ofensivo',
    detail?: string,
    reportId = newId(),
    key = newId(),
  ) =>
    write('post', '/v1/denuncias', token, key).send({
      id: reportId,
      tipoContenido: type,
      contenidoId: id,
      motivo: reason,
      detalle: detail,
    });
  const decide = (token: string, id: string, action: string, reason: string, key = newId()) =>
    write('post', `/v1/moderacion/casos/${id}/decision`, token, key).send({
      accion: action,
      motivo: reason,
    });

  async function signIn(phone: string): Promise<string> {
    const response = await request(server())
      .post('/v1/dev/sesiones')
      .send({ telefono: phone })
      .expect(201);
    return response.body.tokenDeAcceso as string;
  }

  async function neighbor(level = 2, roles: readonly Role[] = []) {
    const id = newId();
    const phone = `+5191850${String(++sequence).padStart(4, '0')}`;
    await sql`
      INSERT INTO identidad.usuarios (id, telefono, nombre_visible, zona_id, nivel_confianza, roles, creado_en)
      VALUES (${id}, ${phone}, 'Vecino de moderación', ${PILOT_ZONE.id}, ${level}, ${roles}::text[], ${new Date(now.getTime() - 5 * DAY)})
    `.execute(db);
    return { id, phone, token: await signIn(phone) };
  }

  async function publishPost(token: string, id = newId(), title = 'Préstamo de herramientas') {
    await write('post', '/v1/publicaciones', token)
      .send({
        id,
        titulo: title,
        categoria: 'herramientas',
        tipo: 'presto',
        ubicacion: LOCATION,
      })
      .expect(201);
    return id;
  }

  async function makeProvider(token: string) {
    await write('put', '/v1/yo/proveedor', token)
      .send({ nombrePublico: 'Proveedor de moderación' })
      .expect(200);
  }

  function publishService(token: string, id: string) {
    return write('post', '/v1/servicios', token).send({
      id,
      categoriaId: 'gasfiteria',
      titulo: 'Reparo una cañería',
      ubicacion: LOCATION,
    });
  }

  async function publishReview(
    token: string,
    serviceId: string,
    comment: string,
    rating = 4,
    fileIds?: string[],
  ) {
    const id = newId();
    await write('post', '/v1/resenas', token)
      .send({
        id,
        servicioId: serviceId,
        calificacion: rating,
        comentario: comment,
        fotos: fileIds,
      })
      .expect(201);
    return id;
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

  async function deliver(type: string, id: string, saved?: OutboxJob) {
    const event = saved ?? (await events(type, id)).at(-1);
    if (!event) throw new Error(`Falta el evento ${type} de ${id}.`);
    await queue.enqueue(type, event);
    await queue.drain();
    return event;
  }

  async function visibleOnWall(token: string, id: string): Promise<boolean> {
    const response = await get('/v1/publicaciones', token)
      .query({ ...LOCATION, radio: 300, limite: 50 })
      .expect(200);
    return response.body.datos.some((post: { id: string }) => post.id === id);
  }

  async function reviewState(id: string) {
    const result = await sql<{
      estado: string;
      motivo_estado: string | null;
      publicada_en: Date | null;
    }>`
      SELECT estado, motivo_estado, publicada_en FROM reputacion.resenas WHERE id = ${id}
    `.execute(db);
    return result.rows[0];
  }

  async function caseOf(type: string, id: string) {
    const { rows } = await sql<{ id: string; estado: string; motivo: string }>`
      SELECT id, estado, motivo FROM moderacion.casos WHERE tipo_contenido = ${type} AND contenido_id = ${id}
    `.execute(db);
    return rows[0];
  }

  beforeAll(async () => {
    ({ app } = await createTestApp(inject('databaseUrl'), {}, (builder) =>
      builder
        .overrideProvider(CLOCK)
        .useValue(clock)
        .overrideProvider(IMAGE_MODERATION)
        .useValue(imageFilter)
        .overrideProvider(REVIEW_PHOTO_READER)
        .useValue(photos),
    ));
    await app.listen(0, '127.0.0.1');
    db = createKysely(inject('databaseUrl'), 4);
    queue = new InMemoryJobQueue(clock);
    await app.get(JobHandlerRegistry).startAll(queue);
  });

  beforeEach(() => {
    now = NOW;
  });
  afterEach(() => vi.restoreAllMocks());
  afterAll(async () => {
    await app?.close();
    await db?.destroy();
  });

  it('registra una denuncia de nivel 0, oculta el muro con auditoría y restaura aunque llegue un evento antiguo', async () => {
    const author = await neighbor();
    const reporter = await neighbor(0);
    const moderator = await neighbor(0, ['moderador']);
    const id = await publishPost(author.token);
    const detail = `El detalle cita el teléfono ${reporter.phone}`;
    expect(await visibleOnWall(reporter.token, id)).toBe(true);
    expect(
      (await report(reporter.token, 'publicacion', id, 'inexistente').expect(400)).body.codigo,
    ).toBe('validacion');
    expect(
      (await report(reporter.token, 'publicacion', id, 'otro', 'x'.repeat(501)).expect(400)).body
        .codigo,
    ).toBe('validacion');
    await report(reporter.token, 'publicacion', newId()).expect(404);

    const reportId = newId();
    const key = newId();
    const first = await report(
      reporter.token,
      'publicacion',
      id,
      'ofensivo',
      detail,
      reportId,
      key,
    ).expect(201);
    const replay = await report(
      reporter.token,
      'publicacion',
      id,
      'ofensivo',
      detail,
      reportId,
      key,
    ).expect(200);
    expect(replay.headers['idempotent-replayed']).toBe('true');
    expect(replay.body).toEqual(first.body);
    expect(
      (await report(author.token, 'publicacion', id, 'ofensivo', detail, reportId).expect(409)).body
        .codigo,
    ).toBe('id_en_uso');
    const caseId = first.body.casoId as string;
    expect(await events(REPORT_EVENT, reportId)).toHaveLength(1);
    await deliver(REPORT_EVENT, reportId);
    const queueResponse = await get('/v1/moderacion/casos', moderator.token)
      .query({ limite: 50 })
      .expect(200);
    expect(queueResponse.body.datos).toContainEqual(
      expect.objectContaining({ id: caseId, estado: 'pendiente' }),
    );
    expect(queueResponse.text).not.toContain(reporter.phone);
    expect(queueResponse.text).not.toContain(detail);
    expect((await get('/v1/moderacion/casos', reporter.token).expect(403)).body.codigo).toBe(
      'rol_requerido',
    );
    await decide(reporter.token, caseId, 'ocultar', 'No permitido').expect(403);

    const decisionKey = newId();
    const reason = `Se confirmó la denuncia sin publicar ${reporter.phone}`;
    await decide(moderator.token, caseId, 'ocultar', ' ').expect(400);
    const resolved = await decide(moderator.token, caseId, 'ocultar', reason, decisionKey).expect(
      200,
    );
    expect(resolved.body).toMatchObject({
      estado: 'resuelto',
      ultimaAccion: 'ocultar',
      primeraRevisionEn: now.toISOString(),
    });
    expect(
      (await decide(moderator.token, caseId, 'ocultar', reason, decisionKey).expect(200)).headers[
        'idempotent-replayed'
      ],
    ).toBe('true');
    const firstHide = await deliver(CONTENT_HIDDEN, id);
    expect(firstHide.carga).toEqual({
      tipoContenido: 'publicacion',
      contenidoId: id,
      motivo: 'moderado',
    });
    expect(await visibleOnWall(reporter.token, id)).toBe(false);
    expect(
      (
        await sql`SELECT id FROM solidaridad.publicaciones WHERE id = ${id} AND oculta_en IS NULL`.execute(
          db,
        )
      ).rows,
    ).toEqual([]);
    const audit =
      await sql`SELECT moderador_id, accion, motivo, decidida_en FROM moderacion.decisiones WHERE caso_id = ${caseId}`.execute(
        db,
      );
    expect(audit.rows).toEqual([
      { moderador_id: moderator.id, accion: 'ocultar', motivo: reason, decidida_en: now },
    ]);

    now = new Date(now.getTime() + 45_000);
    const restored = await decide(
      moderator.token,
      caseId,
      'restaurar',
      'Se levantó el ocultamiento',
    ).expect(200);
    expect(restored.body.primeraRevisionEn).toBe(NOW.toISOString());
    await deliver(CONTENT_RESTORED, id);
    await deliver(CONTENT_HIDDEN, id, firstHide);
    expect(await visibleOnWall(reporter.token, id)).toBe(true);
  });

  it('envía al moderador publicaciones dudosas del muro y permite decidir su publicación', async () => {
    const author = await neighbor(1);
    const moderator = await neighbor(0, ['moderador']);
    const id = await publishPost(author.token, newId(), 'Insulto: imbécil');
    await deliver('solidaridad.publicacion_creada', id);
    const pending = await caseOf('publicacion', id);
    expect(pending).toMatchObject({ estado: 'pendiente', motivo: 'texto_bloqueado' });
    await deliver(CONTENT_HIDDEN, id);
    expect(await visibleOnWall(author.token, id)).toBe(false);
    await decide(moderator.token, pending!.id, 'publicar', 'Revisado como una cita').expect(200);
    await deliver(CONTENT_APPROVED, id);
    expect(await visibleOnWall(author.token, id)).toBe(true);
  });

  it('publica reseñas limpias automáticamente, mantiene los insultos en revisión y recalcula al decidir', async () => {
    const provider = await neighbor();
    await makeProvider(provider.token);
    const serviceId = newId();
    await publishService(provider.token, serviceId).expect(201);
    const clean = await publishReview(
      (await neighbor()).token,
      serviceId,
      'Arreglo bien hecho.',
      4,
    );
    const rude = await publishReview((await neighbor()).token, serviceId, '¡IMBÉCIL!', 1);
    const moderated = await publishReview(
      (await neighbor(1)).token,
      serviceId,
      'Trabajo bien hecho.',
      2,
    );
    expect(await reviewState(clean)).toMatchObject({ estado: 'en_revision' });

    for (const id of [clean, rude, moderated]) await deliver(REVIEW_CREATED, id);
    expect(await caseOf('resena', clean)).toBeUndefined();
    expect(await caseOf('resena', rude)).toMatchObject({
      estado: 'pendiente',
      motivo: 'texto_bloqueado',
    });
    expect(await events(CONTENT_APPROVED, rude)).toEqual([]);
    expect(await reviewState(rude)).toMatchObject({ estado: 'en_revision', publicada_en: null });

    await deliver(CONTENT_APPROVED, clean);
    await deliver(CONTENT_APPROVED, clean);
    expect(await reviewState(clean)).toMatchObject({ estado: 'publicada', publicada_en: now });
    expect(await events(REVIEW_PUBLISHED, clean)).toHaveLength(1);
    expect(await events(RECALCULATE, serviceId)).toHaveLength(1);

    const moderator = await neighbor(0, ['moderador']);
    const pending = await caseOf('resena', moderated);
    expect(pending?.motivo).toBe('autor_no_verificado');
    await decide(moderator.token, pending!.id, 'publicar', 'Reseña válida tras revisión').expect(
      200,
    );
    await deliver(CONTENT_APPROVED, moderated);
    await deliver(RECALCULATE, serviceId);
    await deliver(AGGREGATES, serviceId);
    const facts = () =>
      sql`SELECT total_resenas, suma_calificaciones FROM directorio.servicios WHERE id = ${serviceId}`.execute(
        db,
      );
    expect((await facts()).rows).toEqual([{ total_resenas: 2, suma_calificaciones: 6 }]);

    const reporter = await signIn(NEIGHBORS.ana.phone);
    const reportCase = (await report(reporter, 'resena', clean, 'informacion_falsa').expect(201))
      .body.casoId as string;
    await decide(
      moderator.token,
      reportCase,
      'ocultar',
      'La reseña no corresponde a este servicio',
    ).expect(200);
    await deliver(CONTENT_HIDDEN, clean);
    await deliver(RECALCULATE, serviceId);
    await deliver(AGGREGATES, serviceId);
    expect(await reviewState(clean)).toMatchObject({ estado: 'oculta', motivo_estado: 'moderado' });
    expect((await facts()).rows).toEqual([{ total_resenas: 1, suma_calificaciones: 2 }]);
  });

  it('usa el puerto de imágenes y oculta o restaura una foto sin alterar la reseña publicada', async () => {
    const author = await neighbor();
    const moderator = await neighbor(0, ['moderador']);
    const fileId = newId();
    photos.files.set(fileId, {
      id: fileId,
      ownerId: author.id,
      state: 'listo',
      purpose: 'resena',
      width: 400,
      height: 300,
      blurhash: null,
    });
    const inspect = vi.spyOn(imageFilter, 'inspect').mockResolvedValue('dudosa');
    const reviewId = await publishReview(
      author.token,
      DEMO_SERVICES[0].id,
      'Servicio puntual.',
      4,
      [fileId],
    );
    await deliver(REVIEW_CREATED, reviewId);
    expect(inspect).toHaveBeenCalledWith(fileId);
    const pending = await caseOf('resena', reviewId);
    expect(pending?.motivo).toBe('imagen_dudosa');
    await decide(moderator.token, pending!.id, 'publicar', 'Archivo revisado manualmente').expect(
      200,
    );
    await deliver(CONTENT_APPROVED, reviewId);
    const { rows } = await sql<{
      id: string;
    }>`SELECT id FROM reputacion.resena_fotos WHERE resena_id = ${reviewId}`.execute(db);
    const photoId = rows[0]!.id;
    const reporter = await neighbor(0);
    const photoCase = (
      await report(reporter.token, 'foto', photoId, 'datos_personales').expect(201)
    ).body.casoId as string;
    await decide(moderator.token, photoCase, 'ocultar', 'Retira la foto denunciada').expect(200);
    await deliver(CONTENT_HIDDEN, photoId);
    const visiblePhoto = () =>
      sql`SELECT id FROM reputacion.resena_fotos WHERE id = ${photoId} AND oculta_en IS NULL`.execute(
        db,
      );
    expect((await visiblePhoto()).rows).toEqual([]);
    expect(await reviewState(reviewId)).toMatchObject({ estado: 'publicada' });
    await decide(moderator.token, photoCase, 'restaurar', 'La imagen puede volver').expect(200);
    await deliver(CONTENT_RESTORED, photoId);
    expect((await visiblePhoto()).rows).toEqual([{ id: photoId }]);
  });

  it('al restaurar un proveedor mantiene oculto el servicio que tiene su propia decisión', async () => {
    const provider = await neighbor();
    const reporter = await neighbor(0);
    const moderator = await neighbor(0, ['moderador']);
    await makeProvider(provider.token);
    const first = newId();
    const second = newId();
    await publishService(provider.token, first).expect(201);
    await publishService(provider.token, second).expect(201);
    const providerCase = (await report(reporter.token, 'proveedor', provider.id).expect(201)).body
      .casoId as string;
    const serviceCase = (await report(reporter.token, 'servicio', first).expect(201)).body
      .casoId as string;
    await decide(moderator.token, providerCase, 'ocultar', 'Perfil denunciado').expect(200);
    await deliver(CONTENT_HIDDEN, provider.id);
    await get(`/v1/proveedores/${provider.id}`, reporter.token).expect(404);
    const syncServices = () =>
      sql<{ id: string }>`SELECT id FROM directorio.servicios
      WHERE proveedor_id = ${provider.id} AND eliminado_en IS NULL AND oculto_en IS NULL ORDER BY id`.execute(
        db,
      );
    expect((await syncServices()).rows).toEqual([]);

    await decide(
      moderator.token,
      serviceCase,
      'ocultar',
      'Servicio denunciado por separado',
    ).expect(200);
    await deliver(CONTENT_HIDDEN, first);
    await decide(moderator.token, providerCase, 'restaurar', 'Se restauró el perfil').expect(200);
    await deliver(CONTENT_RESTORED, provider.id);
    await get(`/v1/proveedores/${provider.id}`, reporter.token).expect(200);
    expect((await syncServices()).rows).toEqual([{ id: second }]);
    const search = await get('/v1/servicios', reporter.token)
      .query({ ...LOCATION, radioM: 300, limite: 50 })
      .expect(200);
    expect(search.body.datos).toEqual(
      expect.arrayContaining([expect.objectContaining({ id: second })]),
    );
    expect(search.body.datos).not.toEqual(
      expect.arrayContaining([expect.objectContaining({ id: first })]),
    );
  });

  it('sanciona durante siete días y bloquea la publicación en los tres módulos hasta el vencimiento', async () => {
    const author = await neighbor();
    const moderator = await neighbor(0, ['moderador']);
    const reporter = await neighbor(0);
    await makeProvider(author.token);
    const postId = await publishPost(author.token);
    const caseId = (await report(reporter.token, 'publicacion', postId, 'peligroso').expect(201))
      .body.casoId as string;
    await decide(moderator.token, caseId, 'sancionar', 'Riesgo confirmado').expect(200);
    await deliver(CONTENT_HIDDEN, postId);
    expect(await visibleOnWall(reporter.token, postId)).toBe(false);
    const isSuspended = app.get<IsSuspended>(IS_SUSPENDED);
    await expect(isSuspended(author.id, now)).resolves.toBe(true);
    await expect(isSuspended(author.id, new Date(now.getTime() + 7 * DAY - 1))).resolves.toBe(true);
    const attempts = [
      write('post', '/v1/publicaciones', author.token).send({
        id: newId(),
        titulo: 'Nuevo aviso',
        categoria: 'agua',
        tipo: 'presto',
      }),
      publishService(author.token, newId()),
      write('put', '/v1/yo/proveedor', author.token).send({
        nombrePublico: 'Nuevo nombre público',
      }),
      write('post', '/v1/resenas', author.token).send({
        id: newId(),
        servicioId: DEMO_SERVICES[0].id,
        calificacion: 5,
      }),
    ];
    for (const attempt of attempts) {
      expect((await attempt.expect(403)).body.codigo).toBe('cuenta_suspendida');
    }
    await report(author.token, 'servicio', DEMO_SERVICES[0].id, 'otro').expect(201);

    now = new Date(now.getTime() + 7 * DAY);
    await expect(isSuspended(author.id, now)).resolves.toBe(false);
    await publishPost(await signIn(author.phone));
  });

  it('exporta denuncias propias y quita su detalle cuando se borra la cuenta del denunciante', async () => {
    const reporter = await neighbor(0);
    const author = await neighbor();
    const id = await publishPost(author.token);
    const detail = `Contacto del denunciante: ${reporter.phone}`;
    const response = await report(
      reporter.token,
      'publicacion',
      id,
      'datos_personales',
      detail,
    ).expect(201);
    const own = await get('/v1/yo/datos', reporter.token).expect(200);
    expect(own.body.modulos.moderacion.denuncias).toEqual([
      expect.objectContaining({ id: response.body.id, detalle: detail }),
    ]);
    const others = await get('/v1/yo/datos', author.token).expect(200);
    expect(others.body.modulos.moderacion.denuncias).toEqual([]);

    await write('delete', '/v1/yo', reporter.token).expect(202);
    await deliver('identidad.cuenta_borrada', reporter.id);
    const remaining =
      await sql`SELECT id FROM moderacion.denuncias WHERE denunciante_id = ${reporter.id}`.execute(
        db,
      );
    expect(remaining.rows).toEqual([]);
    const pending = await caseOf('publicacion', id);
    expect(pending).toMatchObject({
      id: response.body.casoId,
      estado: 'pendiente',
      motivo: 'datos_personales',
    });
  });

  it('pagina por estado sin repetir casos y muestra el p90 de primeras revisiones solo a administradores', async () => {
    now = new Date(NOW.getTime() + 40 * DAY);
    const start = now;
    const author = await neighbor();
    const reporter = await neighbor(0);
    const moderator = await neighbor(0, ['moderador']);
    const admin = await neighbor(0, ['administrador']);
    const cases: string[] = [];
    for (let i = 0; i < 3; i++) {
      const postId = await publishPost(author.token);
      cases.push(
        (await report(reporter.token, 'publicacion', postId, 'otro').expect(201)).body
          .casoId as string,
      );
    }
    now = new Date(start.getTime() + 10_000);
    await decide(moderator.token, cases[0]!, 'descartar', 'No se encontró infracción').expect(200);
    now = new Date(start.getTime() + 30_000);
    await decide(moderator.token, cases[1]!, 'ocultar', 'Se revisó la denuncia').expect(200);
    now = new Date(start.getTime() + 60_000);
    await decide(moderator.token, cases[0]!, 'descartar', 'Segunda revisión sin infracción').expect(
      200,
    );
    const first = await get('/v1/moderacion/casos', moderator.token)
      .query({ estado: 'resuelto', limite: 1 })
      .expect(200);
    const cursor = first.body.siguienteCursor as string;
    expect(cursor).toBeTruthy();
    const next = await get('/v1/moderacion/casos', moderator.token)
      .query({ estado: 'resuelto', limite: 1, cursor })
      .expect(200);
    expect(next.body.datos[0].id).not.toBe(first.body.datos[0].id);
    await get('/v1/moderacion/casos', moderator.token)
      .query({ estado: 'pendiente', cursor })
      .expect(400);
    await get('/v1/moderacion/casos', admin.token).expect(403);

    const path = '/v1/moderacion/metricas';
    const query = { desde: start.toISOString(), hasta: now.toISOString() };
    expect((await get(path, moderator.token).query(query).expect(403)).body.codigo).toBe(
      'rol_requerido',
    );
    const result = await get(path, admin.token).query(query).expect(200);
    expect(result.body).toEqual({
      ...query,
      totalCasos: 3,
      pendientes: 1,
      p90PrimeraRevisionSegundos: 28,
    });
    const empty = await get(path, admin.token)
      .query({ desde: new Date(start.getTime() - DAY).toISOString(), hasta: start.toISOString() })
      .expect(200);
    expect(empty.body).toMatchObject({
      totalCasos: 0,
      pendientes: 0,
      p90PrimeraRevisionSegundos: null,
    });
  });
});
