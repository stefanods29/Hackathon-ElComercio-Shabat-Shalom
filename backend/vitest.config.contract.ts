import { defineConfig } from 'vitest/config';

// Contrato con los clientes (Fase 2, Lote C 2.5): levanta la API real sobre una base temporal y
// ejecuta las pruebas en vivo de la consola contra ella. Necesita `DATABASE_URL_ADMIN` y Flutter.
export default defineConfig({
  resolve: { tsconfigPaths: true },
  test: {
    globals: true,
    root: './',
    include: ['test/contract/**/*.contract-spec.ts'],
    globalSetup: ['test/integration/setup-database.ts'],
    fileParallelism: false,
    testTimeout: 600_000,
    hookTimeout: 120_000,
  },
});
