/**
 * `npm run sync:validate`: validates the Sync Streams configuration with the same parser the
 * PowerSync service uses, before deploying it. Fails on errors; prints the warnings.
 */
import { readFileSync } from 'node:fs';
import { validateSyncConfig } from '@powersync/service-sync-rules';

const configPath = process.argv[2];
if (!configPath) {
  console.error('Uso: tsx scripts/validate-sync-config.ts <ruta/sync-config.yaml>');
  process.exit(2);
}

const yaml = readFileSync(configPath, 'utf8');
const issues = validateSyncConfig(yaml, { defaultSchema: 'public' });
const errors = issues.filter((issue) => issue.type !== 'warning');
const warnings = issues.filter((issue) => issue.type === 'warning');

for (const warning of warnings) {
  console.warn(`⚠ ${warning.message}`);
}
for (const error of errors) {
  console.error(`✗ ${error.message}`);
}
if (errors.length > 0) {
  console.error(`\n${configPath}: ${errors.length} error(es).`);
  process.exit(1);
}
console.log(`✓ ${configPath} es válido (${warnings.length} advertencia(s)).`);
