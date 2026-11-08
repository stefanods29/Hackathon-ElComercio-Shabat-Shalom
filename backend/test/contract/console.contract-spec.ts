import { spawn } from 'node:child_process';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import type { AddressInfo } from 'node:net';
import { tmpdir } from 'node:os';
import path from 'node:path';
import type { INestApplication } from '@nestjs/common';
import { type Kysely, sql } from 'kysely';
import { inject } from 'vitest';
import { NEIGHBORS, PILOT_ZONE } from '../../scripts/seed-data.js';
import {
  RESOURCE_STORE,
  type ResourceStore,
} from '../../src/modules/emergencias/application/ports.js';
import type { Role } from '../../src/shared/auth/actor.js';
import { TokenService } from '../../src/shared/auth/token.service.js';
import { createKysely } from '../../src/shared/db/connection.js';
import { UNIT_OF_WORK, type UnitOfWork } from '../../src/shared/db/unit-of-work.js';
import { newId } from '../../src/shared/domain/ids.js';
import { createTestApp } from '../support/app.js';

/**
 * Phase 2, Lot C 2.5: the console's HTTP adapters against the real Emergencias API. The API runs
 * here on an isolated database with fictitious operation data, and `consola/test/live/` runs
 * against it with the address, ids and short-lived tokens of `VECINAL_API_FIXTURE`.
 */
describe('Contrato de la consola con la API de Emergencias', () => {
  let app: INestApplication;
  let db: Kysely<unknown>;
  let directory: string;

  beforeAll(async () => {
    ({ app } = await createTestApp(inject('databaseUrl'), { EMERGENCIES_ENABLED: 'true' }));
    await app.listen(0, '127.0.0.1');
    db = createKysely(inject('databaseUrl'), 2);
    directory = await mkdtemp(path.join(tmpdir(), 'vecinal-consola-'));
  });

  afterAll(async () => {
    await app?.close();
    await db?.destroy();
    if (directory) await rm(directory, { recursive: true, force: true });
  });

  it('los adaptadores HTTP de la consola cumplen el contrato real', async () => {
    const { port } = app.getHttpServer().address() as AddressInfo;
    const apiUrl = `http://127.0.0.1:${port}`;
    const tokens = app.get(TokenService);
    const people = {
      admin: { id: newId(), phone: '+51979000001', name: 'Administración ficticia' },
      coordinatorA: { id: newId(), phone: '+51979000002', name: 'Coordinadora ficticia A' },
      coordinatorB: { id: newId(), phone: '+51979000003', name: 'Coordinador ficticio B' },
      brigade: { id: newId(), phone: '+51979000004', name: 'Brigadista ficticia' },
    };
    for (const [key, person] of Object.entries(people)) {
      const administrator = key === 'admin';
      await sql`INSERT INTO identidad.usuarios (id, telefono, nombre_visible, zona_id, nivel_confianza, roles)
        VALUES (${person.id}, ${person.phone}, ${person.name}, ${PILOT_ZONE.id},
          ${administrator ? 3 : 0}, ${administrator ? ['administrador'] : []})`.execute(db);
    }
    const tokenFor = async (id: string, roles: Role[], trustLevel = 3) =>
      (
        await tokens.issueAccess({
          id,
          zoneId: PILOT_ZONE.id,
          trustLevel,
          roles,
          sessionId: newId(),
        })
      ).token;
    const minutes = (value: number) => new Date(Date.now() + value * 60_000).toISOString();
    const call = async (route: string, token: string, body: object) => {
      const response = await fetch(`${apiUrl}${route}`, {
        method: 'POST',
        headers: {
          authorization: `Bearer ${token}`,
          'content-type': 'application/json',
          'idempotency-key': newId(),
        },
        body: JSON.stringify(body),
      });
      expect(response.status, `${route}: ${await response.clone().text()}`).toBe(200);
    };

    const adminToken = await tokenFor(people.admin.id, ['administrador']);
    for (const [person, rol] of [
      [people.coordinatorA, 'coordinador'],
      [people.coordinatorB, 'coordinador'],
      [people.brigade, 'brigadista'],
    ] as const) {
      await call('/v1/operacion/habilitaciones', adminToken, {
        id: newId(),
        usuarioId: person.id,
        zonaId: PILOT_ZONE.id,
        rol,
        dniRevisadoEn: minutes(-60),
        capacitacionEn: minutes(-60),
        confidencialidadEn: minutes(-60),
        referenciaRevision: 'Revisión ficticia',
        venceEn: minutes(60 * 24 * 30),
      });
    }
    const coordinatorA = await tokenFor(people.coordinatorA.id, ['coordinador']);
    const coordinatorB = await tokenFor(people.coordinatorB.id, ['coordinador']);
    const shift = (userId: string, rol: string) =>
      call(`/v1/operacion/zonas/${PILOT_ZONE.id}/turnos`, coordinatorA, {
        id: newId(),
        usuarioId: userId,
        rol,
        inicio: minutes(-5),
        fin: minutes(8 * 60),
      });
    await shift(people.coordinatorA.id, 'coordinador');
    await shift(people.brigade.id, 'brigadista');
    await call(`/v1/zonas/${PILOT_ZONE.id}/eventos`, coordinatorA, { id: newId(), nivel: 2 });

    // Three requests of one need in one cell reach the publication threshold. Only coordinator A
    // is on duty while they arrive, so B starts without any of them.
    const neighbor = await tokenFor(NEIGHBORS.ana.id, [], 2);
    const cases: string[] = [];
    const eventId = (
      (await (
        await fetch(`${apiUrl}/v1/zonas/${PILOT_ZONE.id}/cobertura`, {
          headers: { authorization: `Bearer ${neighbor}` },
        })
      ).json()) as { eventoId: string }
    ).eventoId;
    for (const prioridad of ['alta', 'media', 'baja']) {
      const id = newId();
      await call('/v1/pedidos-ayuda', neighbor, {
        id,
        eventoId: eventId,
        necesidad: 'agua',
        prioridad,
        descripcion: `Pedido ficticio de prioridad ${prioridad}`,
        ubicacion: { lat: -12.0855, lng: -77.0355 },
      });
      cases.push(id);
    }
    await shift(people.coordinatorB.id, 'coordinador');
    const uow = app.get<UnitOfWork>(UNIT_OF_WORK, { strict: false });
    const resources = app.get<ResourceStore>(RESOURCE_STORE, { strict: false });
    await uow.run((tx) => resources.refreshAggregates(tx, new Date()));

    const fixture = path.join(directory, 'fixture.json');
    await writeFile(
      fixture,
      JSON.stringify({
        apiUrl,
        zoneId: PILOT_ZONE.id,
        coordinatorA: { id: people.coordinatorA.id, token: coordinatorA },
        coordinatorB: { id: people.coordinatorB.id, token: coordinatorB },
        brigadeId: people.brigade.id,
        brigadeName: people.brigade.name,
        cases,
      }),
      { mode: 0o600 },
    );

    // Asynchronous on purpose: the API answers from this same process while Flutter runs.
    const { code, output } = await new Promise<{ code: number | null; output: string }>(
      (resolve, reject) => {
        const child = spawn('flutter', ['test', 'test/live'], {
          cwd: path.resolve(process.cwd(), '../consola'),
          env: { ...process.env, VECINAL_API_FIXTURE: fixture },
        });
        let text = '';
        child.stdout.on('data', (chunk: Buffer) => (text += chunk.toString()));
        child.stderr.on('data', (chunk: Buffer) => (text += chunk.toString()));
        child.on('error', reject);
        child.on('close', (exit) => resolve({ code: exit, output: text }));
      },
    );
    expect(code, output.slice(-4000)).toBe(0);
    expect(output).toContain('All tests passed');
    // Without the fixture the live tests skip themselves: here all seven must have run.
    expect(output).toContain('+7: All tests passed');
  });
});
