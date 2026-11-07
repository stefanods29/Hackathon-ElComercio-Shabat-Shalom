import { defineConfig } from 'vitest/config';

// Pruebas unitarias: viven junto al código (`*.spec.ts`) y no tocan la base de datos.
export default defineConfig({
  resolve: { tsconfigPaths: true },
  test: {
    globals: true,
    root: './',
    include: ['src/**/*.spec.ts', 'test/load/**/*.spec.ts'],
    coverage: {
      provider: 'v8',
      include: ['src/**/*.ts'],
      exclude: ['src/**/*.spec.ts', 'src/**/migrations/**', 'src/main.ts'],
    },
  },
});
