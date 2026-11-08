import { defineConfig } from 'vitest/config';

// A separate, opt-in suite: its database must be the source replicated by the local service.
export default defineConfig({
  resolve: { tsconfigPaths: true },
  test: {
    globals: true,
    include: ['test/live/**/*.live-spec.ts'],
    fileParallelism: false,
    testTimeout: 300_000,
    hookTimeout: 60_000,
  },
});
