/**
 * `npm run dev:keys`: creates `.env` from `.env.example` with a new ES256 key.
 * If `.env` already exists, it only prints a new key so you can copy it if needed.
 */
import { generateKeyPairSync } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';

const { privateKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
const pem = privateKey.export({ format: 'pem', type: 'pkcs8' }).toString().trim();
const keyLine = `JWT_PRIVATE_KEY_PEM="${pem.replace(/\n/g, '\\n')}"`;

if (existsSync('.env')) {
  console.log('.env ya existe; no lo modifico. Clave nueva por si la necesitas:\n');
  console.log(keyLine);
} else {
  const template = readFileSync('.env.example', 'utf8');
  writeFileSync('.env', template.replace(/^JWT_PRIVATE_KEY_PEM=.*$/m, keyLine), {
    mode: 0o600,
  });
  console.log('Listo: .env creado con una clave ES256 nueva (no lo subas al repositorio).');
}
