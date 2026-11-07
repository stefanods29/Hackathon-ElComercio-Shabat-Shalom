import { parseArgs } from 'node:util';
import { z } from 'zod';
import { loadConfig, loadEnvFile } from '../src/shared/config/app-config.js';
import { createKysely } from '../src/shared/db/connection.js';
import { generateLoadFixture } from './load-fixture.js';

const { values } = parseArgs({
  options: {
    count: { type: 'string', default: '100' },
    zone: { type: 'string' },
    'base-url': { type: 'string', default: 'http://localhost:3000' },
    output: { type: 'string', default: 'tokens.load-tokens.json' },
    lat: { type: 'string', default: '-12.086' },
    lng: { type: 'string', default: '-77.035' },
  },
});
const options = z
  .object({
    count: z.coerce.number().int().min(1).max(100000),
    zone: z.uuid(),
    'base-url': z.url(),
    output: z.string().min(1),
    lat: z.coerce.number().min(-90).max(90),
    lng: z.coerce.number().min(-180).max(180),
  })
  .parse(values);
loadEnvFile();
const config = loadConfig();
const db = createKysely(config.DATABASE_URL, 2);
try {
  const result = await generateLoadFixture(db, config, {
    count: options.count,
    zoneId: options.zone,
    baseUrl: options['base-url'],
    output: options.output,
    location: { lat: options.lat, lng: options.lng },
  });
  console.log(
    JSON.stringify({
      evento: 'capacidad.tokens_generados',
      usuarios: result.count,
      expiraEn: result.expiresAt,
    }),
  );
} finally {
  await db.destroy();
}
