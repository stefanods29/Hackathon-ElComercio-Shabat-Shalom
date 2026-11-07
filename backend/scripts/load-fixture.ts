import { randomBytes } from 'node:crypto';
import { open, unlink } from 'node:fs/promises';
import { type Kysely, sql } from 'kysely';
import { hashRefreshToken } from '../src/modules/identidad/application/create-session.js';
import { TokenService, type IssuedToken } from '../src/shared/auth/token.service.js';
import { systemClock } from '../src/shared/domain/clock.js';
import type { Role } from '../src/shared/auth/actor.js';
import type { AppConfig } from '../src/shared/config/app-config.js';
import { newId } from '../src/shared/domain/ids.js';

export interface LoadFixtureOptions {
  readonly count: number;
  readonly zoneId: string;
  readonly baseUrl: string;
  readonly output: string;
  readonly location: { lat: number; lng: number };
}

/** Synthetic, revocable sessions; never calls OTP or the development sign-in endpoint. */
export async function generateLoadFixture(
  db: Kysely<unknown>,
  config: AppConfig,
  options: LoadFixtureOptions,
) {
  if (!Number.isInteger(options.count) || options.count < 1 || options.count > 100_000)
    throw new Error('count debe estar entre 1 y 100000.');
  const url = new URL(options.baseUrl);
  if (
    !['http:', 'https:'].includes(url.protocol) ||
    url.username ||
    url.password ||
    url.search ||
    url.hash
  )
    throw new Error('base-url debe ser una URL HTTP sin credenciales, consulta ni fragmento.');
  const zone = await sql`SELECT id FROM identidad.zonas WHERE id = ${options.zoneId}`.execute(db);
  if (zone.rows.length !== 1) throw new Error('La zona de carga no existe.');
  const file = await open(options.output, 'wx', 0o600);
  try {
    const now = systemClock.now();
    const tokens = new TokenService(config, { now: () => now });
    const phoneBase = BigInt('0x' + randomBytes(6).toString('hex')) % 1_000_000_000_000n;
    const identities = Array.from({ length: options.count + 1 }, (_, index) => ({
      id: newId(),
      familyId: newId(),
      phone:
        '+999' + ((phoneBase + BigInt(index)) % 1_000_000_000_000n).toString().padStart(12, '0'),
      roles: index === options.count ? (['administrador'] as Role[]) : ([] as Role[]),
      refreshHash: hashRefreshToken(
        randomBytes(32).toString('base64url'),
        config.REFRESH_TOKEN_SECRET,
      ),
    }));
    const signed: IssuedToken[] = [];
    for (const identity of identities)
      signed.push(
        await tokens.issueAccess({
          id: identity.id,
          zoneId: options.zoneId,
          trustLevel: 1,
          roles: identity.roles,
          sessionId: identity.familyId,
        }),
      );
    const manifest = {
      version: 1,
      runId: newId(),
      generatedAt: now.toISOString(),
      expiresAt: signed[0]!.expiresAt.toISOString(),
      baseUrl: options.baseUrl.replace(/\/$/, ''),
      maxPostsPerDay: config.MAX_POSTS_PER_DAY,
      location: options.location,
      users: identities
        .slice(0, options.count)
        .map((identity, index) => ({ id: identity.id, token: signed[index]!.token })),
      observerToken: signed.at(-1)!.token,
    };
    await db.transaction().execute(async (transaction) => {
      for (let offset = 0; offset < identities.length; offset += 500) {
        const batch = identities.slice(offset, offset + 500);
        await sql`INSERT INTO identidad.usuarios (id, telefono, nombre_visible, zona_id, nivel_confianza, roles)
          VALUES ${sql.join(batch.map((identity) => sql`(${identity.id}, ${identity.phone}, 'Usuario sintético de carga', ${options.zoneId}, 1, ${sql.val(identity.roles)}::text[])`))}`.execute(
          transaction,
        );
        await sql`INSERT INTO identidad.sesiones (usuario_id, familia_id, refresh_hash, dispositivo, creada_en, expira_en)
          VALUES ${sql.join(batch.map((identity) => sql`(${identity.id}, ${identity.familyId}, ${identity.refreshHash}, 'k6', ${now}, ${new Date(now.getTime() + config.REFRESH_TOKEN_DAYS * 86_400_000)})`))}`.execute(
          transaction,
        );
      }
      await file.writeFile(JSON.stringify(manifest));
    });
    return { count: options.count, expiresAt: manifest.expiresAt, runId: manifest.runId };
  } catch (error) {
    await unlink(options.output);
    throw error;
  } finally {
    await file.close();
  }
}
