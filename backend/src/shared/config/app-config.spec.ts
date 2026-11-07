import { generateKeyPairSync } from 'node:crypto';
import { loadConfig } from './app-config.js';

const pem = generateKeyPairSync('ec', { namedCurve: 'prime256v1' })
  .privateKey.export({ format: 'pem', type: 'pkcs8' })
  .toString();

const base = {
  DATABASE_URL: 'postgres://u:c@localhost:5432/vecinal',
  JWT_PRIVATE_KEY_PEM: pem,
  POWERSYNC_URL: 'http://localhost:8080',
  OTP_HASH_SECRET: 'secreto-de-pruebas-de-32-caracteres-minimo',
};

describe('loadConfig', () => {
  it('aplica valores por defecto seguros', () => {
    const config = loadConfig(base);
    expect(config.PORT).toBe(3000);
    expect(config.ENABLE_DEV_SESSION).toBe(false);
    expect(config.JWT_ACCESS_MINUTES).toBe(15);
    expect(config.TRUST_PROXY_HOPS).toBe(0);
    expect(config.OTP_PROVIDER).toBe('fake');
    expect(config.OTP_MAX_ATTEMPTS_PER_IP).toBe(20);
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

  it('no permite el proveedor OTP falso en producción', () => {
    expect(() => loadConfig({ ...base, NODE_ENV: 'production' })).toThrow(/OTP_PROVIDER/);
  });

  it('exige todas las credenciales de Twilio cuando se selecciona ese proveedor', () => {
    expect(() => loadConfig({ ...base, OTP_PROVIDER: 'twilio' })).toThrow(/TWILIO_ACCOUNT_SID/);
  });

  it('falla rápido y con el motivo si falta algo', () => {
    expect(() => loadConfig({ ...base, DATABASE_URL: 'mysql://x' })).toThrow(/DATABASE_URL/);
    expect(() => loadConfig({ ...base, JWT_PRIVATE_KEY_PEM: 'nada' })).toThrow(/PKCS#8/);
    expect(() => loadConfig({ ...base, OTP_MAX_ATTEMPTS_PER_IP: '0' })).toThrow(
      /OTP_MAX_ATTEMPTS_PER_IP/,
    );
  });
});
