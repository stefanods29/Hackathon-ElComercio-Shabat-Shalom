import { sql } from 'kysely';
import type { TestProject } from 'vitest/node';
import { seed } from '../../scripts/seed-data.js';
import { createKysely } from '../../src/shared/db/connection.js';
import { migrateToLatest } from '../../src/shared/db/migrator.js';

declare module 'vitest' {
  export interface ProvidedContext {
    databaseUrl: string;
    appliedMigrations: string[];
  }
}

const DATABASE_NAME = `vecinal_pruebas_${process.pid}`;

/**
 * Creates a temporary database, applies EVERY migration of every module and seeds the demo
 * neighbors. Drops it at the end. Requires `DATABASE_URL_ADMIN`.
 */
export default async function setup(project: TestProject): Promise<() => Promise<void>> {
  const adminUrl = process.env.DATABASE_URL_ADMIN;
  if (!adminUrl) {
    throw new Error(
      'Define DATABASE_URL_ADMIN (p. ej., postgres://postgres:postgres@localhost:5432/postgres)',
    );
  }
  const admin = createKysely(adminUrl, 1);
  await sql.raw(`DROP DATABASE IF EXISTS ${DATABASE_NAME} WITH (FORCE)`).execute(admin);
  await sql.raw(`CREATE DATABASE ${DATABASE_NAME}`).execute(admin);

  const url = new URL(adminUrl);
  url.pathname = `/${DATABASE_NAME}`;
  const db = createKysely(url.toString(), 2);
  try {
    const applied = await migrateToLatest(db);
    await seed(db);
    project.provide('databaseUrl', url.toString());
    project.provide('appliedMigrations', applied);
  } finally {
    await db.destroy();
  }

  return async () => {
    await sql.raw(`DROP DATABASE IF EXISTS ${DATABASE_NAME} WITH (FORCE)`).execute(admin);
    await admin.destroy();
  };
}
