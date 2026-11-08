import { setTimeout as delay } from 'node:timers/promises';
import type { INestApplication } from '@nestjs/common';
import { decodeJwt } from 'jose';
import { type Kysely, sql } from 'kysely';
import request from 'supertest';
import { inject } from 'vitest';
import { NEIGHBORS, PILOT_ZONE } from '../../scripts/seed-data.js';
import type { RenewableSessionResponse } from '../../src/modules/identidad/api/schemas.js';
import { hashRefreshToken } from '../../src/modules/identidad/application/create-session.js';
import { OTP_PROVIDER } from '../../src/modules/identidad/application/ports.js';
import {
  SESSION_REPOSITORY,
  type SessionRepository,
} from '../../src/modules/identidad/application/session-ports.js';
import { FakeOtpProvider } from '../../src/modules/identidad/infrastructure/fake-otp.provider.js';
import { TokenService } from '../../src/shared/auth/token.service.js';
import { APP_CONFIG, type AppConfig } from '../../src/shared/config/app-config.js';
import { createKysely } from '../../src/shared/db/connection.js';
import { newId } from '../../src/shared/domain/ids.js';
import { createTestApp } from '../support/app.js';

describe('Sesiones revocables', () => {
  let app: INestApplication;
  let provider: FakeOtpProvider;
  let tokens: TokenService;
  let db: Kysely<unknown>;
  let phoneSequence = 0;

  const server = () => app.getHttpServer();
  const newPhone = () => `+5191400${String(++phoneSequence).padStart(4, '0')}`;
  const refresh = (token: string) =>
    request(server()).post('/v1/auth/refrescar').send({ refreshToken: token });
  const sync = (token: string) =>
    request(server()).get('/v1/sync/credenciales').auth(token, { type: 'bearer' });
  const close = (token: string) =>
    request(server()).post('/v1/auth/cerrar-sesion').auth(token, { type: 'bearer' });
  const revokeAll = (token: string) =>
    request(server()).post('/v1/auth/sesiones/revocar').auth(token, { type: 'bearer' });
  const chooseZone = (token: string) =>
    request(server())
      .put('/v1/yo/zona')
      .auth(token, { type: 'bearer' })
      .set('Idempotency-Key', newId())
      .send({ zonaId: PILOT_ZONE.id });

  async function login(
    phone = newPhone(),
    device = 'teléfono de prueba',
  ): Promise<RenewableSessionResponse> {
    await request(server()).post('/v1/auth/otp').send({ telefono: phone }).expect(202);
    const response = await request(server())
      .post('/v1/auth/otp/verificar')
      .send({ telefono: phone, codigo: provider.lastCodeFor(phone), dispositivo: device })
      .expect(200);
    return response.body as RenewableSessionResponse;
  }

  beforeAll(async () => {
    ({ app } = await createTestApp(inject('databaseUrl'), { OTP_MAX_REQUESTS_PER_IP: '1000' }));
    provider = app.get(OTP_PROVIDER) as FakeOtpProvider;
    tokens = app.get(TokenService);
    db = createKysely(inject('databaseUrl'), 4);
  });

  afterEach(() => vi.restoreAllMocks());
  afterAll(async () => {
    await app?.close();
    await db?.destroy();
  });

  it('aplica la migración privada, guarda HMAC y vincula sid con la familia', async () => {
    expect(inject('appliedMigrations')).toContain('202611070200_identidad_sesiones');
    const session = await login();
    const actor = await tokens.verifyAccess(session.tokenDeAcceso);
    const { rows } = await sql<{
      refresh_hash: string;
      familia_id: string;
      dispositivo: string;
      expira_en: Date;
    }>`
      SELECT refresh_hash, familia_id, dispositivo, expira_en FROM identidad.sesiones
      WHERE usuario_id = ${session.usuario.id}
    `.execute(db);
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({
      refresh_hash: hashRefreshToken(
        session.refreshToken,
        app.get<AppConfig>(APP_CONFIG).REFRESH_TOKEN_SECRET,
      ),
      familia_id: actor.sessionId,
      dispositivo: 'teléfono de prueba',
    });
    expect(rows[0]?.refresh_hash).not.toBe(session.refreshToken);
    expect(rows[0]?.expira_en.toISOString()).toBe(session.refreshExpiraEn);
    await expect(
      sql`
      INSERT INTO identidad.sesiones (usuario_id, familia_id, refresh_hash, expira_en)
      VALUES (${session.usuario.id}, ${actor.sessionId}, ${rows[0]!.refresh_hash}, now() + interval '1 day')
    `.execute(db),
    ).rejects.toThrow(/unique/i);
    const publication = await sql<{ name: string }>`
      SELECT tablename AS name FROM pg_publication_tables WHERE pubname = 'powersync' AND tablename = 'sesiones'
    `.execute(db);
    expect(publication.rows).toEqual([]);
  });

  it('emite credenciales de PowerSync con la familia de cada celular autenticado', async () => {
    const phone = newPhone();
    const first = await login(phone, 'primer celular');
    const second = await login(phone, 'segundo celular');
    const firstActor = await tokens.verifyAccess(first.tokenDeAcceso);
    const secondActor = await tokens.verifyAccess(second.tokenDeAcceso);
    expect(firstActor.sessionId).toBeDefined();
    expect(secondActor.sessionId).not.toBe(firstActor.sessionId);

    for (const [session, actor] of [
      [first, firstActor],
      [second, secondActor],
    ] as const) {
      const credential = await sync(session.tokenDeAcceso).expect(200);
      expect(decodeJwt(credential.body.token)).toMatchObject({
        sub: actor.id,
        sid: actor.sessionId,
      });
    }
  });

  it('rota una vez y detecta el token robado: revoca también el refresh nuevo', async () => {
    const session = await login();
    const renewed = await refresh(session.refreshToken).expect(200);
    expect(renewed.body.refreshToken).not.toBe(session.refreshToken);
    const originalActor = await tokens.verifyAccess(session.tokenDeAcceso);
    await expect(tokens.verifyAccess(renewed.body.tokenDeAcceso)).resolves.toMatchObject({
      sessionId: originalActor.sessionId,
    });
    const reused = await refresh(session.refreshToken).expect(401);
    expect(reused.body.codigo).toBe('sesion_revocada');
    expect((await refresh(renewed.body.refreshToken).expect(401)).body.codigo).toBe(
      'sesion_revocada',
    );
    expect((await sync(renewed.body.tokenDeAcceso).expect(401)).body.codigo).toBe(
      'sesion_revocada',
    );
    const { rows } = await sql<{ motivo: string; revoked: boolean }>`
      SELECT motivo, revocada_en IS NOT NULL AS revoked FROM identidad.sesiones WHERE usuario_id = ${session.usuario.id}
    `.execute(db);
    expect(rows).toEqual([
      { motivo: 'reutilizacion', revoked: true },
      { motivo: 'reutilizacion', revoked: true },
    ]);
  });

  it('serializa dos renovaciones del mismo refresh y revoca la familia por reutilización', async () => {
    const session = await login();
    const results = await Promise.all([
      refresh(session.refreshToken),
      refresh(session.refreshToken),
    ]);
    expect(results.map((result) => result.status).sort((left, right) => left - right)).toEqual([
      200, 401,
    ]);
    const succeeded = results.find((result) => result.status === 200)!;
    expect((await refresh(succeeded.body.refreshToken).expect(401)).body.codigo).toBe(
      'sesion_revocada',
    );
    const { rows } = await sql<{ active: number }>`
      SELECT count(*)::int AS active FROM identidad.sesiones WHERE usuario_id = ${session.usuario.id} AND revocada_en IS NULL
    `.execute(db);
    expect(rows[0]?.active).toBe(0);
  });

  it('la reutilización cierra únicamente la familia afectada', async () => {
    const phone = newPhone();
    const first = await login(phone, 'A');
    const second = await login(phone, 'B');
    await refresh(first.refreshToken).expect(200);
    await refresh(first.refreshToken).expect(401);
    await sync(second.tokenDeAcceso).expect(200);
    await refresh(second.refreshToken).expect(200);
  });

  it('relee el estado actual del vecino al renovar', async () => {
    const session = await login();
    await sql`
      UPDATE identidad.usuarios SET zona_id = ${PILOT_ZONE.id}, nivel_confianza = 3,
        roles = ARRAY['moderador']::text[] WHERE id = ${session.usuario.id}
    `.execute(db);
    const renewed = await refresh(session.refreshToken).expect(200);
    expect(renewed.body.usuario).toMatchObject({
      zonaId: PILOT_ZONE.id,
      nivel: 3,
      roles: ['moderador'],
    });
    await expect(tokens.verifyAccess(renewed.body.tokenDeAcceso)).resolves.toMatchObject({
      zoneId: PILOT_ZONE.id,
      trustLevel: 3,
      roles: ['moderador'],
    });
  });

  it('rechaza refresh desconocidos y vencidos sin rotarlos', async () => {
    expect((await refresh('desconocido').expect(401)).body.codigo).toBe('sesion_invalida');
    const session = await login();
    await sql`UPDATE identidad.sesiones SET expira_en = now() - interval '1 second' WHERE usuario_id = ${session.usuario.id}`.execute(
      db,
    );
    expect((await refresh(session.refreshToken).expect(401)).body.codigo).toBe('sesion_invalida');
    expect((await sync(session.tokenDeAcceso).expect(401)).body.codigo).toBe('sesion_revocada');
    const { rows } = await sql<{
      rotada_en: Date | null;
    }>`SELECT rotada_en FROM identidad.sesiones WHERE usuario_id = ${session.usuario.id}`.execute(
      db,
    );
    expect(rows).toEqual([{ rotada_en: null }]);
  });

  it('la familia no está activa si solo sus filas históricas rotadas siguen vigentes', async () => {
    const session = await login();
    const renewed = await refresh(session.refreshToken).expect(200);
    await sql`UPDATE identidad.sesiones SET expira_en = now() - interval '1 second'
      WHERE usuario_id = ${session.usuario.id} AND rotada_en IS NULL`.execute(db);
    expect((await sync(renewed.body.tokenDeAcceso).expect(401)).body.codigo).toBe(
      'sesion_revocada',
    );
  });

  it('revoca la familia si la cuenta fue eliminada y no crea otra fila', async () => {
    const session = await login();
    await sql`UPDATE identidad.usuarios SET eliminado_en = now() WHERE id = ${session.usuario.id}`.execute(
      db,
    );
    expect((await refresh(session.refreshToken).expect(401)).body.codigo).toBe('sesion_revocada');
    const { rows } = await sql<{ active: number; total: number }>`SELECT count(*)::int AS total,
      count(*) FILTER (WHERE revocada_en IS NULL)::int AS active FROM identidad.sesiones WHERE usuario_id = ${session.usuario.id}`.execute(
      db,
    );
    expect(rows).toEqual([{ total: 1, active: 0 }]);
  });

  it('cerrar una familia es idempotente y no cierra el otro dispositivo', async () => {
    const phone = newPhone();
    const first = await login(phone, 'A');
    const second = await login(phone, 'B');
    await close(first.tokenDeAcceso).expect(204);
    await close(first.tokenDeAcceso).expect(204);
    expect((await sync(first.tokenDeAcceso).expect(401)).body.codigo).toBe('sesion_revocada');
    expect((await refresh(first.refreshToken).expect(401)).body.codigo).toBe('sesion_revocada');
    await sync(second.tokenDeAcceso).expect(200);
    await refresh(second.refreshToken).expect(200);
    // Existing access remains valid until its short expiry, as specified.
    await expect(tokens.verifyAccess(first.tokenDeAcceso)).resolves.toMatchObject({
      id: first.usuario.id,
    });
  });

  it('revocar todo desde B corta A y B, pero permite un nuevo inicio por OTP', async () => {
    const phone = newPhone();
    const first = await login(phone, 'A');
    const second = await login(phone, 'B');
    await revokeAll(second.tokenDeAcceso).expect(204);
    await revokeAll(second.tokenDeAcceso).expect(204);
    for (const session of [first, second]) {
      expect((await refresh(session.refreshToken).expect(401)).body.codigo).toBe('sesion_revocada');
      expect((await sync(session.tokenDeAcceso).expect(401)).body.codigo).toBe('sesion_revocada');
    }
    const third = await login(phone, 'C');
    await sync(third.tokenDeAcceso).expect(200);
    await refresh(third.refreshToken).expect(200);
  });

  it('revocar todo espera una rotación en curso e incluye la fila recién insertada', async () => {
    const session = await login();
    const repository = app.get<SessionRepository>(SESSION_REPOSITORY);
    const original = repository.markRotated.bind(repository);
    const entered = Promise.withResolvers<void>();
    const release = Promise.withResolvers<void>();
    vi.spyOn(repository, 'markRotated').mockImplementationOnce(async (...args) => {
      await original(...args);
      entered.resolve();
      await release.promise;
    });
    const rotating = refresh(session.refreshToken).then((response) => response);
    await entered.promise;
    const revoking = revokeAll(session.tokenDeAcceso).then((response) => response);
    let waiting = false;
    try {
      const deadline = Date.now() + 5_000;
      while (Date.now() < deadline) {
        const { rows } = await sql<{ waiting: boolean }>`SELECT EXISTS (
          SELECT 1 FROM pg_stat_activity WHERE datname = current_database() AND wait_event = 'advisory'
        ) AS waiting`.execute(db);
        if (rows[0]?.waiting) {
          waiting = true;
          break;
        }
        await delay(10);
      }
    } finally {
      release.resolve();
    }
    const [renewed, revoked] = await Promise.all([rotating, revoking]);
    expect(waiting).toBe(true);
    expect(renewed.status).toBe(200);
    expect(revoked.status).toBe(204);
    expect((await refresh(renewed.body.refreshToken).expect(401)).body.codigo).toBe(
      'sesion_revocada',
    );
    expect((await sync(renewed.body.tokenDeAcceso).expect(401)).body.codigo).toBe(
      'sesion_revocada',
    );
  });

  it('una familia ajena no permite sync ni es revocada por cerrar sesión de otro vecino', async () => {
    const owner = await login();
    const other = await login();
    const ownerActor = await tokens.verifyAccess(owner.tokenDeAcceso);
    const otherActor = await tokens.verifyAccess(other.tokenDeAcceso);
    const { token } = await tokens.issueAccess({ ...otherActor, sessionId: ownerActor.sessionId });
    expect((await sync(token).expect(401)).body.codigo).toBe('sesion_revocada');
    await close(token).expect(204);
    await sync(owner.tokenDeAcceso).expect(200);
    await refresh(owner.refreshToken).expect(200);
  });

  it('elegir zona conserva sid y el token nuevo respeta el cierre posterior', async () => {
    const session = await login();
    const chosen = await chooseZone(session.tokenDeAcceso).expect(200);
    const actor = await tokens.verifyAccess(session.tokenDeAcceso);
    await expect(tokens.verifyAccess(chosen.body.tokenDeAcceso)).resolves.toMatchObject({
      sessionId: actor.sessionId,
      zoneId: PILOT_ZONE.id,
    });
    expect(chosen.body).not.toHaveProperty('refreshToken');
    await close(chosen.body.tokenDeAcceso).expect(204);
    expect((await sync(chosen.body.tokenDeAcceso).expect(401)).body.codigo).toBe('sesion_revocada');
  });

  it('no permite emitir acceso nuevo al elegir zona después de revocar la familia', async () => {
    const session = await login();
    await close(session.tokenDeAcceso).expect(204);
    expect((await chooseZone(session.tokenDeAcceso).expect(401)).body.codigo).toBe(
      'sesion_revocada',
    );
    const { rows } = await sql<{
      zona_id: string | null;
    }>`SELECT zona_id FROM identidad.usuarios WHERE id = ${session.usuario.id}`.execute(db);
    expect(rows).toEqual([{ zona_id: null }]);
  });

  it('exige autenticación para cerrar y revocar todas las sesiones', async () => {
    await request(server()).post('/v1/auth/cerrar-sesion').expect(401);
    await request(server()).post('/v1/auth/sesiones/revocar').expect(401);
  });

  it('valida el cuerpo de renovación antes de buscar el token', async () => {
    for (const body of [
      {},
      { refreshToken: '' },
      { refreshToken: 42 },
      { refreshToken: 'a'.repeat(513) },
    ]) {
      const response = await request(server()).post('/v1/auth/refrescar').send(body).expect(400);
      expect(response.body.codigo).toBe('validacion');
    }
  });

  it('conserva la sesión de desarrollo sin refresh ni sid y su cierre es inocuo', async () => {
    const response = await request(server())
      .post('/v1/dev/sesiones')
      .send({ telefono: NEIGHBORS.ana.phone })
      .expect(201);
    expect(response.body).not.toHaveProperty('refreshToken');
    await expect(tokens.verifyAccess(response.body.tokenDeAcceso)).resolves.not.toHaveProperty(
      'sessionId',
    );
    await close(response.body.tokenDeAcceso).expect(204);
    await sync(response.body.tokenDeAcceso).expect(200);
  });

  it('consumo OTP y creación de sesión se revierten juntos si falla la firma', async () => {
    const phone = newPhone();
    await request(server()).post('/v1/auth/otp').send({ telefono: phone }).expect(202);
    const body = { telefono: phone, codigo: provider.lastCodeFor(phone) };
    vi.spyOn(tokens, 'issueAccess').mockRejectedValueOnce(new Error('fallo simulado de firma'));
    await request(server()).post('/v1/auth/otp/verificar').send(body).expect(500);
    const codes = await sql<{
      usado_en: Date | null;
    }>`SELECT usado_en FROM identidad.codigos_otp WHERE telefono = ${phone}`.execute(db);
    expect(codes.rows).toEqual([{ usado_en: null }]);
    const users = await sql<{
      count: number;
    }>`SELECT count(*)::int AS count FROM identidad.usuarios WHERE telefono = ${phone}`.execute(db);
    expect(users.rows[0]?.count).toBe(0);
    await request(server()).post('/v1/auth/otp/verificar').send(body).expect(200);
  });

  it('la rotación real se revierte si falla la firma y el token original sigue sirviendo', async () => {
    const session = await login();
    vi.spyOn(tokens, 'issueAccess').mockRejectedValueOnce(new Error('fallo simulado de firma'));
    await refresh(session.refreshToken).expect(500);
    const { rows } = await sql<{ total: number; rotated: number }>`SELECT count(*)::int AS total,
      count(*) FILTER (WHERE rotada_en IS NOT NULL)::int AS rotated FROM identidad.sesiones WHERE usuario_id = ${session.usuario.id}`.execute(
      db,
    );
    expect(rows).toEqual([{ total: 1, rotated: 0 }]);
    await refresh(session.refreshToken).expect(200);
  });
});
