/** `npm run db:seed`: loads the demo zones and neighbors (development only). */
import { loadConfig, loadEnvFile } from '../src/shared/config/app-config.js';
import { createKysely } from '../src/shared/db/connection.js';
import { NEIGHBORS, PILOT_ZONE, seed } from './seed-data.js';

loadEnvFile();
const config = loadConfig();
if (config.NODE_ENV === 'production') {
  console.error('La semilla de demostración no se carga en producción.');
  process.exit(1);
}

const db = createKysely(config.DATABASE_URL, 1);
try {
  await seed(db);
  console.log(`Zona sembrada: ${PILOT_ZONE.name} (${PILOT_ZONE.id})`);
  for (const neighbor of Object.values(NEIGHBORS)) {
    console.log(`  · ${neighbor.name}: ${neighbor.phone} (nivel ${neighbor.trustLevel})`);
  }
} finally {
  await db.destroy();
}
