import { defineConfig } from 'vitest/config';

// Pruebas de integración: usan un PostgreSQL real con PostGIS.
// `DATABASE_URL_ADMIN` apunta a un usuario que puede crear bases de datos;
// la configuración global crea una base temporal, la migra, la siembra y la borra al final.
export default defineConfig({
  resolve: { tsconfigPaths: true },
  test: {
    globals: true,
    root: './',
    include: ['test/integration/**/*.int-spec.ts'],
    globalSetup: ['test/integration/setup-database.ts'],
    fileParallelism: false,
    testTimeout: 30_000,
    hookTimeout: 60_000,
  },
});
