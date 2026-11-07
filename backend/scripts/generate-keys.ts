/**
 * `npm run dev:keys`: creates `.env` with a new ES256 key and independent HMAC secrets.
 * If `.env` already exists, it only prints new secrets so you can copy them if needed.
 */
import { generateKeyPairSync, randomBytes } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';

const { privateKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
const pem = privateKey.export({ format: 'pem', type: 'pkcs8' }).toString().trim();
const keyLine = `JWT_PRIVATE_KEY_PEM="${pem.replace(/\n/g, '\\n')}"`;
const otpSecretLine = `OTP_HASH_SECRET=${randomBytes(32).toString('base64url')}`;
const refreshSecretLine = `REFRESH_TOKEN_SECRET=${randomBytes(32).toString('base64url')}`;

if (existsSync('.env')) {
  console.log('.env ya existe; no lo modifico. Claves nuevas por si las necesitas:\n');
  console.log(keyLine);
  console.log(otpSecretLine);
  console.log(refreshSecretLine);
} else {
  const template = readFileSync('.env.example', 'utf8');
  const env = template
    .replace(/^JWT_PRIVATE_KEY_PEM=.*$/m, keyLine)
    .replace(/^OTP_HASH_SECRET=.*$/m, otpSecretLine)
    .replace(/^REFRESH_TOKEN_SECRET=.*$/m, refreshSecretLine);
  writeFileSync('.env', env, { mode: 0o600 });
  console.log('Listo: .env creado con claves nuevas (no lo subas al repositorio).');
}
