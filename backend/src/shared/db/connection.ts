import { Kysely, PostgresDialect } from 'kysely';
import pg from 'pg';

export const KYSELY = Symbol('KYSELY');

/**
 * One connection pool for the whole monolith. Each module receives it typed with only its own
 * tables plus the shared ones, so the compiler stops it from reading another module's tables.
 */
export function createKysely(
  databaseUrl: string,
  maxConnections = 10,
  options: pg.PoolConfig = {},
): Kysely<unknown> {
  return new Kysely<unknown>({
    dialect: new PostgresDialect({
      pool: new pg.Pool({ connectionString: databaseUrl, max: maxConnections, ...options }),
    }),
  });
}
