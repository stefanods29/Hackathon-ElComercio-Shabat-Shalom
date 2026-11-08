import type { INestApplication } from '@nestjs/common';
import { type Kysely, sql } from 'kysely';
import request from 'supertest';
import { inject } from 'vitest';
import { NEIGHBORS, NEIGHBOR_ZONE, PILOT_ZONE } from '../../scripts/seed-data.js';
import type { Role } from '../../src/shared/auth/actor.js';
import { TokenService } from '../../src/shared/auth/token.service.js';
import { createKysely } from '../../src/shared/db/connection.js';
import { newId } from '../../src/shared/domain/ids.js';
import { createTestApp } from '../support/app.js';

/**
 * Phase 2 end to end through the API (milestone H2): a coordinator activates the event, a neighbor
 * asks for help, the coordinator sees the queue, assigns a brigade member, who goes on the way,
 * and the neighbor confirms the attention. It also checks what the phone's streams receive
 * (Lot A) and what the console reads (Lot C).
 */
describe('Emergencias por HTTP y PostgreSQL', () => {
  // Fresh accounts with their own phone numbers (other suites use +51911…): the grants raise
  // their trust and roles, so the seed neighbors stay untouched.
  const admin = { id: newId(), phone: '+51977000001', name: 'Administración de prueba' };
  const coordinatorA = { id: newId(), phone: '+51977000002', name: 'Coordinadora A' };
  const coordinatorB = { id: newId(), phone: '+51977000003', name: 'Coordinador B' };
  const brigade = { id: newId(), phone: '+51977000004', name: 'Brigadista de prueba' };
  const accounts = [admin, coordinatorA, coordinatorB, brigade];
  const eventId = newId();
  const requestId = newId();
  const groupId = newId();
  const resourceId = newId();
  const grantId = newId();
  const shiftId = newId();
  const location = { lat: -12.085, lng: -77.035 };

  let app: INestApplication;
  let db: Kysely<unknown>;
  let tokens: TokenService;
  const sessions = new Map<string, string>();
  const server = () => app.getHttpServer();

  async function tokenFor(
    id: string,
    roles: Role[],
    trustLevel = 3,
    zoneId: string = PILOT_ZONE.id,
  ): Promise<string> {
    const sessionId = sessions.get(id) ?? newId();
    sessions.set(id, sessionId);
    return (await tokens.issueAccess({ id, zoneId, trustLevel, roles, sessionId })).token;
  }
  const post = (path: string, token: string, body: object, key = newId()) =>
    request(server())
      .post(path)
      .auth(token, { type: 'bearer' })
      .set('Idempotency-Key', key)
      .send(body);
  const get = (path: string, token: string) =>
    request(server()).get(path).auth(token, { type: 'bearer' });
  const neighbor = () => tokenFor(NEIGHBORS.ana.id, [], 2);
  const coordinator = () => tokenFor(coordinatorA.id, ['coordinador']);
  const brigadeMember = () => tokenFor(brigade.id, ['brigadista']);
  const minutes = (value: number) => new Date(Date.now() + value * 60_000).toISOString();

  async function grant(userId: string, rol: 'coordinador' | 'brigadista') {
    const token = await tokenFor(admin.id, ['administrador']);
    const response = await post('/v1/operacion/habilitaciones', token, {
      id: userId === coordinatorA.id ? grantId : newId(),
      usuarioId: userId,
      zonaId: PILOT_ZONE.id,
      rol,
      dniRevisadoEn: minutes(-60),
      capacitacionEn: minutes(-60),
      confidencialidadEn: minutes(-60),
      referenciaRevision: 'Revisión de prueba',
      venceEn: minutes(60 * 24 * 30),
    }).expect(200);
    expect(response.body).toMatchObject({ usuarioId: userId, rol, revocadaEn: null });
  }

  async function shift(userId: string, rol: 'coordinador' | 'brigadista') {
    await post(`/v1/operacion/zonas/${PILOT_ZONE.id}/turnos`, await coordinator(), {
      id: userId === coordinatorA.id ? shiftId : newId(),
      usuarioId: userId,
      rol,
      inicio: minutes(-5),
      fin: minutes(8 * 60),
    }).expect(200);
  }

  async function exactCopies() {
    return (
      await sql<{ pedido_id: string; lat: number; lng: number }>`
        SELECT pedido_id, lat, lng FROM emergencias.ubicaciones_en_camino
        WHERE pedido_id = ${requestId}`.execute(db)
    ).rows;
  }

  async function currentVersion(): Promise<number> {
    const { rows } = await sql<{ version: number }>`
      SELECT version FROM emergencias.pedidos_ayuda WHERE id = ${requestId}`.execute(db);
    return rows[0]!.version;
  }

  beforeAll(async () => {
    ({ app } = await createTestApp(inject('databaseUrl'), {
      EMERGENCIES_ENABLED: 'true',
      SMS_PROVIDER: 'fake',
    }));
    db = createKysely(inject('databaseUrl'), 2);
    tokens = app.get(TokenService);
    for (const account of accounts) {
      const administrator = account === admin;
      await sql`INSERT INTO identidad.usuarios (id, telefono, nombre_visible, zona_id, nivel_confianza, roles)
        VALUES (${account.id}, ${account.phone}, ${account.name}, ${PILOT_ZONE.id},
          ${administrator ? 3 : 0}, ${administrator ? ['administrador'] : []})`.execute(db);
    }
  });

  afterAll(async () => {
    await app?.close();
    if (db) {
      // Other suites share the database: no active event or shift stays behind.
      await sql`UPDATE emergencias.eventos SET estado = 'normal', cerrado_en = now()
        WHERE id = ${eventId}`.execute(db);
      await sql`UPDATE emergencias.turnos SET finalizado_en = now() WHERE finalizado_en IS NULL
        AND usuario_id = ANY(${accounts.map((account) => account.id)}::uuid[])`.execute(db);
      await sql`UPDATE identidad.usuarios SET eliminado_en = now()
        WHERE id = ANY(${accounts.map((account) => account.id)}::uuid[])`.execute(db);
    }
    await db?.destroy();
  });

  it('sin coordinación habilitada la zona no admite pedidos', async () => {
    const coverage = await get(`/v1/zonas/${PILOT_ZONE.id}/cobertura`, await neighbor()).expect(
      200,
    );
    expect(coverage.body).toMatchObject({ zonaId: PILOT_ZONE.id, habilitada: false });
  });

  it('habilita a dos coordinadores y una brigadista con su turno y activa el evento', async () => {
    await grant(coordinatorA.id, 'coordinador');
    await grant(coordinatorB.id, 'coordinador');
    await grant(brigade.id, 'brigadista');
    const { rows } = await sql<{ roles: string[]; nivel_confianza: number }>`
      SELECT roles, nivel_confianza FROM identidad.usuarios WHERE id = ${brigade.id}`.execute(db);
    expect(rows[0]).toEqual({ roles: ['brigadista'], nivel_confianza: 3 });

    await shift(coordinatorA.id, 'coordinador');
    await shift(brigade.id, 'brigadista');
    const event = await post(`/v1/zonas/${PILOT_ZONE.id}/eventos`, await coordinator(), {
      id: eventId,
      nivel: 2,
    }).expect(200);
    expect(event.body).toMatchObject({ id: eventId, estado: 'emergencia', zonaId: PILOT_ZONE.id });

    const coverage = await get(`/v1/zonas/${PILOT_ZONE.id}/cobertura`, await neighbor()).expect(
      200,
    );
    expect(coverage.body).toMatchObject({
      habilitada: true,
      eventoId: eventId,
      modo: 'emergencia',
      coordinadoresActivos: 2,
      coordinadoresDeTurno: 1,
    });
  });

  it('el vecino pide ayuda con el id del celular y un reintento no duplica el pedido', async () => {
    const body = {
      id: requestId,
      eventoId: eventId,
      necesidad: 'agua',
      prioridad: 'alta',
      descripcion: 'Adulto mayor sin agua desde ayer',
      ubicacion: location,
    };
    const key = newId();
    const created = await post('/v1/pedidos-ayuda', await neighbor(), body, key).expect(200);
    expect(created.body).toMatchObject({ id: requestId, estado: 'enviado', version: 1 });
    expect(created.body).not.toHaveProperty('descripcion');
    const replay = await post('/v1/pedidos-ayuda', await neighbor(), body, key).expect(200);
    expect(replay.headers['idempotent-replayed']).toBe('true');
    expect(replay.body).toEqual(created.body);
    const differentBody = await post(
      '/v1/pedidos-ayuda',
      await neighbor(),
      {
        ...body,
        id: newId(),
      },
      key,
    ).expect(422);
    expect(differentBody.body.codigo).toBe('idempotency_key_reutilizada');
    const { rows } = await sql<{ count: number }>`
      SELECT count(*)::int AS count FROM emergencias.pedidos_ayuda WHERE id = ${requestId}`.execute(
      db,
    );
    expect(rows[0]!.count).toBe(1);

    const lifeRisk = await post('/v1/pedidos-ayuda', await neighbor(), {
      ...body,
      id: newId(),
      riesgoVital: true,
    }).expect(409);
    expect(lifeRisk.body.codigo).toBe('riesgo_vital');
  });

  it('oculta el pedido ajeno, incluso al coordinador sin asignación', async () => {
    const other = await tokenFor(NEIGHBORS.beto.id, [], 1);
    const unassigned = await tokenFor(coordinatorB.id, ['coordinador']);
    const missing = newId();
    for (const token of [other, unassigned]) {
      const real = await get(`/v1/pedidos-ayuda/${requestId}`, token).expect(404);
      const absent = await get(`/v1/pedidos-ayuda/${missing}`, token).expect(404);
      expect(real.body.codigo).toBe(absent.body.codigo);
      await post(`/v1/pedidos-ayuda/${requestId}/estado`, token, {
        versionVista: 1,
        estado: 'visto',
      }).expect(404);
    }
    await post(`/v1/pedidos-ayuda/${requestId}/prioridad`, unassigned, {
      versionVista: 1,
      prioridad: 'baja',
      motivo: 'Control de prueba',
    }).expect(404);
    expect(await currentVersion()).toBe(1);
  });

  it('las rutas operativas por id rechazan vecinos, roles solo en el token y nivel insuficiente', async () => {
    await post(
      `/v1/operacion/zonas/${PILOT_ZONE.id}/grupos`,
      await tokenFor(admin.id, ['administrador']),
      {
        id: groupId,
        nombre: 'Grupo de prueba',
        miembros: [],
      },
    ).expect(200);
    const lowTrust = await tokenFor(coordinatorA.id, ['coordinador'], 2);
    const roleOnlyInToken = await tokenFor(NEIGHBORS.ana.id, ['coordinador'], 3);
    const write = { versionVista: 1, motivo: 'Control de prueba' };

    for (const token of [await neighbor(), lowTrust, roleOnlyInToken]) {
      await get(`/v1/eventos/${eventId}/resumen`, token).expect(403);
      await post(`/v1/eventos/${eventId}/cerrar`, token, write).expect(403);
      await post(`/v1/operacion/habilitaciones/${grantId}/revocar`, token, write).expect(403);
      await post(`/v1/operacion/turnos/${shiftId}/finalizar`, token, { versionVista: 1 }).expect(
        403,
      );
      await request(server())
        .put(`/v1/operacion/grupos/${groupId}/miembros`)
        .auth(token, { type: 'bearer' })
        .set('Idempotency-Key', newId())
        .send({ versionVista: 1, miembros: [brigade.id] })
        .expect(403);
      await post(`/v1/pedidos-ayuda/${requestId}/asignaciones`, token, {
        versionVista: 1,
        usuarioId: brigade.id,
      }).expect(403);
      await post(`/v1/pedidos-ayuda/${requestId}/prioridad`, token, {
        ...write,
        prioridad: 'baja',
      }).expect(403);
      await post(`/v1/pedidos-ayuda/${requestId}/accesos-sincronizacion`, token, {
        alcance: 'resumen',
      }).expect(403);
    }
  });

  it('separa permisos de recursos y rechaza lecturas y escrituras desde otra zona', async () => {
    const outsider = await tokenFor(NEIGHBORS.elena.id, [], 2, NEIGHBOR_ZONE.id);
    const other = await tokenFor(NEIGHBORS.beto.id, [], 1);
    const resource = `/v1/recursos-criticos/${resourceId}`;
    const update = (token: string) =>
      request(server())
        .patch(resource)
        .auth(token, { type: 'bearer' })
        .set('Idempotency-Key', newId())
        .send({ versionVista: 1, cantidad: 20 });
    await post(`/v1/zonas/${PILOT_ZONE.id}/recursos`, await neighbor(), {
      id: resourceId,
      tipo: 'agua',
      cantidad: 10,
      ubicacion: location,
    }).expect(200);
    for (const segment of ['eventos', 'cobertura', 'recursos', 'celdas']) {
      await get(`/v1/zonas/${PILOT_ZONE.id}/${segment}`, outsider).expect(404);
    }
    await update(outsider).expect(404);
    await update(other).expect(403);
    await post(`${resource}/confirmaciones`, outsider, { versionVista: 1 }).expect(404);
    await post(`${resource}/verificacion`, other, {
      versionVista: 1,
      etiqueta: 'Recurso de prueba',
      oficial: false,
    }).expect(403);
    const authorized = await post(`${resource}/confirmaciones`, other, { versionVista: 1 }).expect(
      200,
    );
    expect(authorized.body).toMatchObject({ cantidad: 10, confirmaciones: 1 });
  });

  it('curaduría no permite leer ni editar archivos a una cuenta sin rol autorizado', async () => {
    const base = '/v1/operacion/directorio-emergencia';
    const file = `${base}/distrito-prueba.json`;
    const token = await tokenFor(NEIGHBORS.ana.id, ['curador'], 3);
    await request(server()).get(file).expect(401);
    await get(base, token).expect(403);
    await get(file, token).expect(403);
    await request(server())
      .put(file)
      .auth(token, { type: 'bearer' })
      .set('Idempotency-Key', newId())
      .send({ versionVista: 1, distrito: 'Distrito de prueba', entradas: [{}] })
      .expect(403);
    await get(`${base}/..%2Fprivado.json`, await coordinator()).expect(400);
  });

  it('la cola de la consola muestra el caso sin descripción ni coordenadas', async () => {
    const queue = await get(
      `/v1/operacion/zonas/${PILOT_ZONE.id}/casos`,
      await coordinator(),
    ).expect(200);
    const item = queue.body.elementos.find((entry: { id: string }) => entry.id === requestId);
    expect(item).toMatchObject({ necesidad: 'agua', prioridad: 'alta', estado: 'enviado' });
    expect(item.asignaciones).toEqual([
      expect.objectContaining({ usuarioId: coordinatorA.id, rol: 'coordinador' }),
    ]);
    expect(JSON.stringify(queue.body)).not.toMatch(/Adulto mayor|-12\.085|-77\.035/);
    expect(queue.headers['cache-control']).toContain('no-store');
  });

  it('el coordinador lo marca visto y asigna a la brigadista de turno', async () => {
    const seen = await post(`/v1/pedidos-ayuda/${requestId}/estado`, await coordinator(), {
      versionVista: 1,
      estado: 'visto',
    }).expect(200);
    expect(seen.body).toMatchObject({ estado: 'visto', version: 2 });
    const stale = await post(`/v1/pedidos-ayuda/${requestId}/asignaciones`, await coordinator(), {
      versionVista: 1,
      usuarioId: brigade.id,
      rol: 'brigadista',
    }).expect(409);
    expect(stale.body.codigo).toBe('conflicto_de_version');
    await post(`/v1/pedidos-ayuda/${requestId}/asignaciones`, await coordinator(), {
      versionVista: 2,
      usuarioId: brigade.id,
      rol: 'brigadista',
    }).expect(200);
  });

  it('la brigadista ve la ubicación exacta solo cuando sale en camino', async () => {
    const before = await get(`/v1/pedidos-ayuda/${requestId}`, await brigadeMember()).expect(200);
    expect(before.body).toMatchObject({ estado: 'visto', ubicacionExacta: null });

    // Lot A, part 2: the phone opens the case's streams with a permission tied to this session.
    const openAccess = async (alcance: 'resumen' | 'exacta') =>
      post(`/v1/pedidos-ayuda/${requestId}/accesos-sincronizacion`, await brigadeMember(), {
        alcance,
      });
    const summary = await openAccess('resumen');
    expect(summary.status).toBe(200);
    expect(summary.body).toMatchObject({ pedidoId: requestId, alcance: 'resumen' });
    expect((await openAccess('resumen')).body.autorizacionId).toBe(summary.body.autorizacionId);
    const early = await openAccess('exacta');
    expect(early.status).toBe(409);
    expect(early.body.codigo).toBe('ubicacion_no_disponible');
    const withoutSession = await post(
      `/v1/pedidos-ayuda/${requestId}/accesos-sincronizacion`,
      (
        await tokens.issueAccess({
          id: brigade.id,
          zoneId: PILOT_ZONE.id,
          trustLevel: 3,
          roles: ['brigadista'],
        })
      ).token,
      { alcance: 'resumen' },
    ).expect(403);
    expect(withoutSession.body.codigo).toBe('sesion_requerida');
    const stranger = await post(
      `/v1/pedidos-ayuda/${requestId}/accesos-sincronizacion`,
      await tokenFor(coordinatorB.id, ['coordinador']),
      { alcance: 'resumen' },
    );
    expect(stranger.status).toBe(404);
    expect(await exactCopies()).toEqual([]);
    const onTheWay = await post(`/v1/pedidos-ayuda/${requestId}/estado`, await brigadeMember(), {
      versionVista: await currentVersion(),
      estado: 'en_camino',
    }).expect(200);
    expect(onTheWay.body.estado).toBe('en_camino');
    const after = await get(`/v1/pedidos-ayuda/${requestId}`, await brigadeMember()).expect(200);
    expect(after.body.ubicacionExacta).toEqual(location);
    expect(after.body.descripcion).toBe('Adulto mayor sin agua desde ayer');

    // The stream copy exists only while the case is on the way.
    expect(await exactCopies()).toEqual([
      { pedido_id: requestId, lat: location.lat, lng: location.lng },
    ]);
    const exact = await post(
      `/v1/pedidos-ayuda/${requestId}/accesos-sincronizacion`,
      await brigadeMember(),
      { alcance: 'exacta' },
    ).expect(200);
    expect(exact.body.alcance).toBe('exacta');
  });

  it('solo el vecino confirma la atención y ve su historial', async () => {
    const notOwner = await post(`/v1/pedidos-ayuda/${requestId}/estado`, await brigadeMember(), {
      versionVista: await currentVersion(),
      estado: 'atendido',
    }).expect(403);
    expect(notOwner.body.codigo).toBe('confirmacion_del_vecino_requerida');
    await post(`/v1/pedidos-ayuda/${requestId}/estado`, await neighbor(), {
      versionVista: await currentVersion(),
      estado: 'atendido',
    }).expect(200);
    const own = await get(`/v1/pedidos-ayuda/${requestId}`, await neighbor()).expect(200);
    expect(own.body.estado).toBe('atendido');
    expect(own.body.historial.map((entry: { hasta: string }) => entry.hasta)).toEqual([
      'enviado',
      'visto',
      'en_camino',
      'atendido',
    ]);
    expect(own.body.asignaciones).toEqual([]);

    // Closing removes the exact copy and revokes every stream permission of the case.
    expect(await exactCopies()).toEqual([]);
    const { rows: permits } = await sql<{ revocada_en: Date | null }>`
      SELECT revocada_en FROM emergencias.autorizaciones_stream WHERE pedido_id = ${requestId}`.execute(
      db,
    );
    expect(permits).toHaveLength(2);
    expect(permits.every((permit) => permit.revocada_en !== null)).toBe(true);

    // The author's stream reads a copy of the history without the operator or operational notes.
    const { rows: history } = await sql<Record<string, unknown>>`
      SELECT * FROM emergencias.historial_para_autor WHERE pedido_id = ${requestId} ORDER BY id`.execute(
      db,
    );
    expect(history.map((row) => row.hasta)).toEqual(['enviado', 'visto', 'en_camino', 'atendido']);
    expect(history.every((row) => row.motivo_para_autor === null)).toBe(true);
    expect(Object.keys(history[0]!)).not.toContain('usuario_id');
  });

  it('cada acceso a un dato sensible queda auditado sin su contenido', async () => {
    const { rows } = await sql<{ accion: string }>`
      SELECT accion FROM emergencias.auditoria WHERE pedido_id = ${requestId} ORDER BY id`.execute(
      db,
    );
    const actions = rows.map((row) => row.accion);
    expect(actions).toEqual(
      expect.arrayContaining([
        'pedido_creado',
        'cola_consultada',
        'estado_actualizado',
        'asignacion_actualizada',
        'detalle_consultado',
        'ubicacion_exacta_consultada',
        'caso_abierto_en_celular',
        'ubicacion_exacta_autorizada',
      ]),
    );
    expect(JSON.stringify(rows)).not.toMatch(/Adulto mayor|-12\.085/);
  });
});
