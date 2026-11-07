import { readdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import type { Kysely } from 'kysely';
import { type Migration, type MigrationProvider, Migrator } from 'kysely/migration';

/**
 * Collects the migrations of the whole monolith. Each module owns its own and keeps them in its
 * `migrations/` folder. File names are global and sortable: `YYYYMMDDHHmm_<modulo>_<descripcion>.ts`.
 */
export class ModularMigrationProvider implements MigrationProvider {
  constructor(
    private readonly root: string,
    private readonly extension: '.ts' | '.js',
  ) {}

  async getMigrations(): Promise<Record<string, Migration>> {
    const files = (await readdir(this.root, { recursive: true }))
      .filter((file) => file.split(path.sep).includes('migrations'))
      .filter((file) => file.endsWith(this.extension) && !file.endsWith('.d.ts'))
      .filter((file) => !file.includes('.spec.'))
      .sort((a, b) => path.basename(a).localeCompare(path.basename(b)));

    const migrations: Record<string, Migration> = {};
    for (const file of files) {
      const name = path.basename(file, this.extension);
      if (migrations[name]) {
        throw new Error(`Hay dos migraciones con el mismo nombre: ${name}`);
      }
      const loaded = (await import(pathToFileURL(path.join(this.root, file)).href)) as Migration;
      migrations[name] = {
        up: (db) => loaded.up(db),
        ...(loaded.down
          ? { down: (db: Kysely<unknown>) => loaded.down?.(db) ?? Promise.resolve() }
          : {}),
      };
    }
    return migrations;
  }
}

/** Source root (`src/` in development with tsx, `dist/` in production). */
function sourceRoot(): { root: string; extension: '.ts' | '.js' } {
  const file = fileURLToPath(import.meta.url);
  return {
    root: path.resolve(path.dirname(file), '..', '..'),
    extension: file.endsWith('.ts') ? '.ts' : '.js',
  };
}

export function createMigrator(db: Kysely<unknown>): Migrator {
  const { root, extension } = sourceRoot();
  return new Migrator({
    db,
    provider: new ModularMigrationProvider(root, extension),
    // Lots integrate in parallel: a migration can reach main after a newer one.
    allowUnorderedMigrations: true,
    migrationTableSchema: 'compartido',
  });
}

/** Applies every pending migration and throws with the detail if one fails. */
export async function migrateToLatest(db: Kysely<unknown>): Promise<string[]> {
  const { error, results } = await createMigrator(db).migrateToLatest();
  const applied = (results ?? [])
    .filter((result) => result.status === 'Success')
    .map((result) => result.migrationName);
  if (error) {
    const failed = results?.find((result) => result.status === 'Error');
    const reason = error instanceof Error ? error.message : JSON.stringify(error);
    throw new Error(`Falló la migración ${failed?.migrationName ?? '(desconocida)'}: ${reason}`, {
      cause: error,
    });
  }
  return applied;
}
