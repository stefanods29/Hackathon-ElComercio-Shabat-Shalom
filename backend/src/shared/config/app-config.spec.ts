import { generateKeyPairSync } from 'node:crypto';
import { loadConfig } from './app-config.js';

const pem = generateKeyPairSync('ec', { namedCurve: 'prime256v1' })
  .privateKey.export({ format: 'pem', type: 'pkcs8' })
  .toString();

const base = {
  DATABASE_URL: 'postgres://u:c@localhost:5432/vecinal',
  JWT_PRIVATE_KEY_PEM: pem,
  POWERSYNC_URL: 'http://localhost:8080',
};

describe('loadConfig', () => {
  it('aplica valores por defecto seguros', () => {
    const config = loadConfig(base);
    expect(config.PORT).toBe(3000);
    expect(config.ENABLE_DEV_SESSION).toBe(false);
    expect(config.JWT_ACCESS_MINUTES).toBe(15);
  });

  it('acepta la clave PEM en una sola línea con \\n escritos', () => {
    const singleLine = pem.trim().replace(/\n/g, '\\n');
    expect(loadConfig({ ...base, JWT_PRIVATE_KEY_PEM: singleLine }).JWT_PRIVATE_KEY_PEM).toBe(
      pem.trim(),
    );
  });

  it('no permite la sesión de desarrollo en producción', () => {
    expect(() =>
      loadConfig({ ...base, NODE_ENV: 'production', ENABLE_DEV_SESSION: 'true' }),
    ).toThrow(/ENABLE_DEV_SESSION/);
  });

  it('falla rápido y con el motivo si falta algo', () => {
    expect(() => loadConfig({ ...base, DATABASE_URL: 'mysql://x' })).toThrow(/DATABASE_URL/);
    expect(() => loadConfig({ ...base, JWT_PRIVATE_KEY_PEM: 'nada' })).toThrow(/PKCS#8/);
  });

  it('exige FCM real en producción y valida las credenciales sin exponerlas', () => {
    expect(() => loadConfig({ ...base, NODE_ENV: 'production' })).toThrow(/NOTIFICATION_DRIVER/);
    expect(() =>
      loadConfig({
        ...base,
        NOTIFICATION_DRIVER: 'fcm',
        FIREBASE_SERVICE_ACCOUNT_BASE64: 'privado',
      }),
    ).toThrow(/FIREBASE_SERVICE_ACCOUNT_BASE64/);
    const account = Buffer.from(
      JSON.stringify({
        project_id: 'prueba',
        client_email: 'prueba@example.com',
        private_key: pem,
      }),
    ).toString('base64');
    expect(
      loadConfig({
        ...base,
        NODE_ENV: 'production',
        NOTIFICATION_DRIVER: 'fcm',
        FIREBASE_SERVICE_ACCOUNT_BASE64: account,
      }).NOTIFICATION_DRIVER,
    ).toBe('fcm');
  });
});
