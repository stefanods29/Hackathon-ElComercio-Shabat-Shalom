import { mkdtemp, readFile, rm, stat } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { type Kysely, sql } from 'kysely';
import { inject } from 'vitest';
import { generateLoadFixture } from '../../scripts/load-fixture.js';
import { PILOT_ZONE } from '../../scripts/seed-data.js';
import { TokenService } from '../../src/shared/auth/token.service.js';
import { createKysely } from '../../src/shared/db/connection.js';
import { newId } from '../../src/shared/domain/ids.js';
import { testConfig } from '../support/config.js';

describe('Credenciales sintéticas de carga', () => {
  let db: Kysely<unknown>;
  let directory: string;
  const ids: string[] = [];
  const config = testConfig();
  beforeAll(async () => {
    db = createKysely(inject('databaseUrl'), 2);
    directory = await mkdtemp(path.join(tmpdir(), 'vecinal-tokens-test-'));
  });
  afterAll(async () => {
    await sql`DELETE FROM identidad.sesiones WHERE usuario_id = ANY(${ids}::uuid[])`.execute(db);
    await sql`DELETE FROM identidad.usuarios WHERE id = ANY(${ids}::uuid[])`.execute(db);
    await db?.destroy();
    await rm(directory, { recursive: true, force: true });
  });
  const options = () => ({
    count: 3,
    zoneId: PILOT_ZONE.id,
    baseUrl: 'http://localhost:3000',
    output: path.join(directory, 'tokens.load-tokens.json'),
    location: { lat: -12.086, lng: -77.035 },
  });

  it('crea sesiones revocables sin OTP ni sesión de desarrollo y un archivo 0600', async () => {
    await generateLoadFixture(db, config, options());
    const bundle = JSON.parse(await readFile(options().output, 'utf8')) as {
      users: Array<{ id: string; token: string }>;
      observerToken: string;
      expiresAt: string;
    };
    expect(bundle.users).toHaveLength(3);
    expect((await stat(options().output)).mode & 0o777).toBe(0o600);
    const tokens = new TokenService(config, { now: () => new Date() });
    for (const user of bundle.users) {
      ids.push(user.id);
      const actor = await tokens.verifyAccess(user.token);
      expect(actor).toMatchObject({ id: user.id, trustLevel: 1, zoneId: PILOT_ZONE.id, roles: [] });
      const session = await sql<{
        count: number;
      }>`SELECT count(*)::int AS count FROM identidad.sesiones WHERE usuario_id = ${actor.id} AND familia_id = ${actor.sessionId} AND revocada_en IS NULL`.execute(
        db,
      );
      expect(session.rows[0]?.count).toBe(1);
    }
    const observer = await tokens.verifyAccess(bundle.observerToken);
    ids.push(observer.id);
    expect(observer.roles).toEqual(['administrador']);
    expect(Date.parse(bundle.expiresAt)).toBeGreaterThan(Date.now());
    expect(bundle).not.toHaveProperty('refreshToken');
  });

  it('un archivo existente no se sobrescribe y no crea usuarios adicionales', async () => {
    const before = await sql<{
      count: number;
    }>`SELECT count(*)::int AS count FROM identidad.usuarios`.execute(db);
    await expect(generateLoadFixture(db, config, options())).rejects.toMatchObject({
      code: 'EEXIST',
    });
    const after = await sql<{
      count: number;
    }>`SELECT count(*)::int AS count FROM identidad.usuarios`.execute(db);
    expect(after.rows).toEqual(before.rows);
  });

  it('valida la zona y el tamaño antes de crear credenciales', async () => {
    const output = path.join(directory, 'invalid.load-tokens.json');
    await expect(
      generateLoadFixture(db, config, { ...options(), zoneId: newId(), output }),
    ).rejects.toThrow(/zona/);
    await expect(
      generateLoadFixture(db, config, { ...options(), count: 0, output }),
    ).rejects.toThrow(/count/);
    await expect(stat(output)).rejects.toMatchObject({ code: 'ENOENT' });
  });
});
