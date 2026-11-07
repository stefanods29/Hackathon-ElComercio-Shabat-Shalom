import type { INestApplication } from '@nestjs/common';
import { type Kysely, sql } from 'kysely';
import request from 'supertest';
import { v7 as uuidv7 } from 'uuid';
import { inject } from 'vitest';
import { NEIGHBORS, PILOT_ZONE } from '../../scripts/seed-data.js';
import { NOTIFICATION_PORT } from '../../src/modules/notificaciones/application/ports.js';
import { NotificationHandlers } from '../../src/modules/notificaciones/application/notification-handlers.js';
import type { FakeNotificationAdapter } from '../../src/modules/notificaciones/infrastructure/notification.fake.js';
import { KYSELY } from '../../src/shared/db/connection.js';
import { JobHandlerRegistry } from '../../src/shared/queues/job-handler.registry.js';
import { JOB_QUEUE } from '../../src/shared/queues/job-queue.js';
import type { InMemoryJobQueue } from '../../src/shared/queues/job-queue.memory.js';
import { createTestApp } from '../support/app.js';

describe('avisos con PostgreSQL real', () => {
  let app: INestApplication;
  let db: Kysely<unknown>;
  let push: FakeNotificationAdapter;
  let handlers: NotificationHandlers;
  const tokens: Record<string, string> = {};
  const register = (token: string, user = 'ana', key = uuidv7()) =>
    request(app.getHttpServer())
      .post('/v1/dispositivos')
      .set('Authorization', `Bearer ${tokens[user]}`)
      .set('Idempotency-Key', key)
      .send({ token, plataforma: 'android' });
  const job = (avisoId = uuidv7()) => ({
    avisoId,
    destino: { tipo: 'usuario', usuarioId: NEIGHBORS.ana.id },
    plantilla: 'favor_tomado',
    datos: { publicacionId: uuidv7() },
  });

  beforeAll(async () => {
    ({ app } = await createTestApp(inject('databaseUrl')));
    db = app.get(KYSELY);
    push = app.get(NOTIFICATION_PORT);
    handlers = app.get(NotificationHandlers);
    for (const user of ['ana', 'beto'] as const) {
      const response = await request(app.getHttpServer())
        .post('/v1/dev/sesiones')
        .send({ telefono: NEIGHBORS[user].phone })
        .expect(201);
      tokens[user] = response.body.tokenDeAcceso;
    }
  });
  beforeEach(async () => {
    await sql`TRUNCATE notificaciones.entregas_aviso, notificaciones.avisos_enviados, notificaciones.dispositivos`.execute(
      db,
    );
    push.sent.length = 0;
    push.invalidTokens.clear();
    push.failingTokens.clear();
  });
  afterAll(async () => {
    await app?.close();
  });

  it('requiere autenticación, valida el token e impide campos desconocidos', async () => {
    await request(app.getHttpServer()).post('/v1/dispositivos').send({}).expect(401);
    await register('a b').expect(400);
    await register('a'.repeat(4097)).expect(400);
    await register('a'.repeat(4096)).expect(200);
  });

  it('el registro es idempotente, no expone el token y reasigna su dueño', async () => {
    const key = uuidv7();
    const first = await register('dispositivo', 'ana', key).expect(200);
    const retry = await register('dispositivo', 'ana', key).expect(200);
    expect(retry.body).toEqual(first.body);
    expect(Object.keys(first.body).sort()).toEqual(['id', 'plataforma', 'registradoEn']);
    const reassigned = await register('dispositivo', 'beto').expect(200);
    expect(reassigned.body.id).toBe(first.body.id);
    await handlers.send(job());
    expect(push.sent).toHaveLength(0);
  });

  it('la baja solo afecta al dueño y repetirla es seguro', async () => {
    await register('dispositivo').expect(200);
    const revoke = (user: string) =>
      request(app.getHttpServer())
        .post('/v1/dispositivos/baja')
        .set('Authorization', `Bearer ${tokens[user]}`)
        .set('Idempotency-Key', uuidv7())
        .send({ token: 'dispositivo' });
    await revoke('beto').expect(204);
    await handlers.send(job());
    expect(push.sent).toHaveLength(1);
    await revoke('ana').expect(204);
    await revoke('ana').expect(204);
    await handlers.send(job());
    expect(push.sent).toHaveLength(1);
    await register('dispositivo').expect(200);
    await handlers.send(job());
    expect(push.sent).toHaveLength(2);
  });

  it('el mismo trabajo concurrente y repetido produce un solo envío', async () => {
    await register('dispositivo').expect(200);
    const data = job();
    await Promise.all([handlers.send(data), handlers.send(data)]);
    await handlers.send(data);
    expect(push.sent).toHaveLength(1);
    await expect(handlers.send({ ...data, datos: { publicacionId: uuidv7() } })).rejects.toThrow(
      'otro contenido',
    );
  });

  it('un fallo parcial reintenta solo los dispositivos pendientes', async () => {
    await register('primero').expect(200);
    await register('segundo').expect(200);
    push.failingTokens.add('segundo');
    const data = job();
    await expect(handlers.send(data)).rejects.toThrow('temporal');
    expect(push.sent.map((item) => item.destination)).toEqual(['primero']);
    push.failingTokens.clear();
    await handlers.send(data);
    expect(push.sent.map((item) => item.destination)).toEqual(['primero', 'segundo']);
  });

  it('el token inválido queda dado de baja', async () => {
    await register('invalido').expect(200);
    push.invalidTokens.add('invalido');
    await handlers.send(job());
    const result = await sql<{
      dado_de_baja_en: Date | null;
    }>`SELECT dado_de_baja_en FROM notificaciones.dispositivos`.execute(db);
    expect(result.rows[0]?.dado_de_baja_en).toBeInstanceOf(Date);
  });

  it('procesa el evento del relay, evita duplicados y entrega al tópico público', async () => {
    await register('dispositivo').expect(200);
    const queue = app.get<InMemoryJobQueue>(JOB_QUEUE);
    await app.get(JobHandlerRegistry).startAll(queue);
    const event = {
      eventoId: uuidv7(),
      agregadoId: uuidv7(),
      carga: { autorId: NEIGHBORS.ana.id },
    };
    await handlers.favorTaken(event);
    await handlers.favorTaken(event);
    expect(queue.pendingCount).toBe(1);
    await queue.drain();
    await handlers.favorTaken(event);
    await queue.drain();
    expect(push.sent).toHaveLength(1);
    const zone = {
      avisoId: uuidv7(),
      destino: { tipo: 'zona', zonaId: PILOT_ZONE.id },
      plantilla: 'aviso_de_zona',
      datos: {},
    };
    await handlers.send(zone);
    await handlers.send(zone);
    expect(push.sent[1]?.destination).toBe(`zona-${PILOT_ZONE.id}`);
    await expect(handlers.send({ ...zone, datos: { texto: 'privado' } })).rejects.toThrow();
  });
});
