/**
 * Migrations CLI.
 *   npm run db:migrate          → applies every pending migration
 *   npm run db:migrate -- down  → reverts the last one
 */
import { loadConfig, loadEnvFile } from '../config/app-config.js';
import { createKysely } from './connection.js';
import { createMigrator, migrateToLatest } from './migrator.js';

loadEnvFile();
const config = loadConfig();
const db = createKysely(config.DATABASE_URL, 1);

try {
  if (process.argv[2] === 'down') {
    const { error, results } = await createMigrator(db).migrateDown();
    for (const result of results ?? []) {
      console.log(`↓ ${result.migrationName}: ${result.status}`);
    }
    if (error) throw error;
  } else {
    const applied = await migrateToLatest(db);
    console.log(
      applied.length
        ? `Migraciones aplicadas:\n${applied.map((name) => `  ✓ ${name}`).join('\n')}`
        : 'La base de datos ya estaba al día.',
    );
  }
} finally {
  await db.destroy();
}
