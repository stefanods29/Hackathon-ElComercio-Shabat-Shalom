import type { INestApplication } from '@nestjs/common';
import { type Kysely, sql } from 'kysely';
import request from 'supertest';
import { PILOT_ZONE } from '../../scripts/seed-data.js';
import type { Role } from '../../src/shared/auth/actor.js';
import { TokenService } from '../../src/shared/auth/token.service.js';
import { KYSELY } from '../../src/shared/db/connection.js';
import { CLOCK } from '../../src/shared/domain/clock.js';
import { newId } from '../../src/shared/domain/ids.js';
import { JobHandlerRegistry } from '../../src/shared/queues/job-handler.registry.js';
import { JOB_QUEUE } from '../../src/shared/queues/job-queue.js';
import type { InMemoryJobQueue } from '../../src/shared/queues/job-queue.memory.js';
import { createTestApp } from './app.js';

export function emergencyFixture(phonePrefix: string) {
  const admin = newId();
  const coordinators = [newId(), newId()];
  const neighbor = newId();
  const otherNeighbor = newId();
  const accounts = [admin, ...coordinators, neighbor, otherNeighbor];
  const eventId = newId();
  const zoneId = PILOT_ZONE.id;
  const location = { lat: -12.085, lng: -77.035 };
  let now = Date.UTC(2026, 10, 8, 12);
  const clock = { now: () => new Date(now) };
  const secondsFromNow = (seconds: number) => new Date(now + seconds * 1000).toISOString();
  let app: INestApplication | undefined;
  const getApp = () => app!;
  const db = () => getApp().get<Kysely<unknown>>(KYSELY);
  const queue = () => getApp().get<InMemoryJobQueue>(JOB_QUEUE);
  const server = () => request(getApp().getHttpServer());

  async function tokenFor(id: string, roles: Role[] = [], trustLevel = 1): Promise<string> {
    const tokens = getApp().get(TokenService);
    return (await tokens.issueAccess({ id, zoneId, roles, trustLevel })).token;
  }
  const coordinatorToken = (id: string) => tokenFor(id, ['coordinador'], 3);
  const write = (method: 'post' | 'patch', path: string, token: string, body: object) =>
    server()
      [method](path)
      .auth(token, { type: 'bearer' })
      .set('Idempotency-Key', newId())
      .send(body);

  return {
    eventId,
    zoneId,
    location,
    neighbor,
    otherNeighbor,
    coordinators,
    advance(seconds: number) {
      now += seconds * 1000;
    },
    now: clock.now,
    app: getApp,
    db,
    queue,
    tokenFor,
    coordinatorToken,
    write,
    get: (path: string, token: string) => server().get(path).auth(token, { type: 'bearer' }),
    async start(databaseUrl: string, overrides: Record<string, string>) {
      ({ app } = await createTestApp(
        databaseUrl,
        { EMERGENCIES_ENABLED: 'true', JOB_QUEUE_DRIVER: 'memory', ...overrides },
        (builder) => builder.overrideProvider(CLOCK).useValue(clock),
      ));
      await getApp().get(JobHandlerRegistry).startAll(queue());

      for (const [index, id] of accounts.entries()) {
        await sql`INSERT INTO identidad.usuarios
          (id, telefono, nombre_visible, zona_id, nivel_confianza, roles)
          VALUES (${id}, ${phonePrefix + (index + 1)}, ${'Cuenta ficticia ' + index}, ${zoneId},
            ${id === admin ? 3 : 1}, ${id === admin ? ['administrador'] : []})`.execute(db());
      }
      const adminToken = await tokenFor(admin, ['administrador'], 3);
      for (const id of coordinators) {
        await write('post', '/v1/operacion/habilitaciones', adminToken, {
          id: newId(),
          usuarioId: id,
          zonaId: zoneId,
          rol: 'coordinador',
          dniRevisadoEn: secondsFromNow(-3600),
          capacitacionEn: secondsFromNow(-3600),
          confidencialidadEn: secondsFromNow(-3600),
          referenciaRevision: 'Revisión ficticia',
          venceEn: secondsFromNow(86400),
        }).expect(200);
      }
      const token = await coordinatorToken(coordinators[0]!);
      for (const id of coordinators) {
        await write('post', `/v1/operacion/zonas/${zoneId}/turnos`, token, {
          id: newId(),
          usuarioId: id,
          rol: 'coordinador',
          inicio: secondsFromNow(-300),
          fin: secondsFromNow(3600),
        }).expect(200);
      }
      await write('post', `/v1/zonas/${zoneId}/eventos`, token, { id: eventId, nivel: 2 }).expect(
        200,
      );
    },
    async requestHelp(
      prioridad: 'alta' | 'media' | 'baja',
      necesidad: 'agua' | 'alimentos' = 'agua',
    ) {
      const id = newId();
      await write('post', '/v1/pedidos-ayuda', await tokenFor(neighbor), {
        id,
        eventoId: eventId,
        necesidad,
        prioridad,
        descripcion: 'Detalle privado ficticio',
        ubicacion: location,
      }).expect(200);
      return id;
    },
    async initialCoordinator(id: string): Promise<string> {
      const { rows } = await sql<{ usuario_id: string }>`SELECT usuario_id
        FROM emergencias.escalamientos WHERE pedido_id = ${id} AND etapa = 0`.execute(db());
      return rows[0]!.usuario_id;
    },
    async runJob(name: string, data: unknown = {}) {
      await queue().enqueue(name, data);
      await queue().drain();
    },
    async close() {
      if (!app) return;
      try {
        await db()
          .transaction()
          .execute(async (tx) => {
            // Leave no active cases, assignments, event, shifts or devices in the shared database.
            const endedAt = clock.now();
            await sql`DELETE FROM compartido.outbox WHERE agregado_id = ${eventId}
            OR agregado_id IN (SELECT id FROM emergencias.pedidos_ayuda WHERE evento_id = ${eventId})`.execute(
              tx,
            );
            await sql`UPDATE emergencias.asignaciones SET finalizada_en = ${endedAt}
            WHERE finalizada_en IS NULL AND pedido_id IN (
              SELECT id FROM emergencias.pedidos_ayuda WHERE evento_id = ${eventId}
            )`.execute(tx);
            await sql`UPDATE emergencias.pedidos_ayuda
            SET estado = 'cerrado_sin_atender', cerrado_en = ${endedAt}, escalar_en = NULL
            WHERE evento_id = ${eventId} AND cerrado_en IS NULL`.execute(tx);
            await sql`UPDATE emergencias.eventos SET estado = 'normal', cerrado_en = ${endedAt}
            WHERE id = ${eventId}`.execute(tx);
            await sql`UPDATE emergencias.turnos SET finalizado_en = ${endedAt}
            WHERE usuario_id = ANY(${coordinators}::uuid[]) AND finalizado_en IS NULL`.execute(tx);
            await sql`DELETE FROM notificaciones.dispositivos
            WHERE usuario_id = ANY(${accounts}::uuid[])`.execute(tx);
            await sql`UPDATE identidad.usuarios SET eliminado_en = ${endedAt}
            WHERE id = ANY(${accounts}::uuid[])`.execute(tx);
          });
      } finally {
        await app.close();
      }
    },
  };
}
