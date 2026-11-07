import { existsSync } from 'node:fs';
import { z } from 'zod';

/** PEM keys may come on a single line with literal `\n` sequences (.env files). */
const pemKey = z
  .string()
  .transform((value) => value.replace(/\\n/g, '\n').trim())
  .pipe(z.string().includes('BEGIN PRIVATE KEY', { message: 'debe ser una clave PKCS#8 en PEM' }));

export const configSchema = z
  .object({
    NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
    PORT: z.coerce.number().int().min(1).max(65_535).default(3000),
    DATABASE_URL: z.string().regex(/^postgres(ql)?:\/\//, 'debe ser una URL postgres://'),
    JWT_ISSUER: z.string().min(1).default('vecinal-api'),
    JWT_KID: z.string().min(1).default('dev-1'),
    JWT_PRIVATE_KEY_PEM: pemKey,
    JWT_ACCESS_MINUTES: z.coerce.number().int().min(1).max(15).default(15),
    JWT_SYNC_MINUTES: z.coerce.number().int().min(1).max(60).default(10),
    POWERSYNC_URL: z.url(),
    ENABLE_DEV_SESSION: z.stringbool().default(false),
    IDEMPOTENCY_RETENTION_HOURS: z.coerce.number().int().min(1).default(168),
    TRUST_PROXY_HOPS: z.coerce.number().int().min(0).default(0),
    OTP_PROVIDER: z.enum(['fake', 'twilio']).default('fake'),
    OTP_HASH_SECRET: z.string().min(32),
    REFRESH_TOKEN_SECRET: z.string().min(32),
    REFRESH_TOKEN_DAYS: z.coerce.number().int().min(1).max(365).default(30),
    OTP_TTL_MINUTES: z.coerce.number().int().min(1).default(5),
    OTP_MAX_REQUESTS_PER_PHONE: z.coerce.number().int().min(1).default(3),
    OTP_MAX_REQUESTS_PER_IP: z.coerce.number().int().min(1).default(20),
    OTP_MAX_ATTEMPTS: z.coerce.number().int().min(1).default(5),
    OTP_MAX_ATTEMPTS_PER_IP: z.coerce.number().int().min(1).default(20),
    OTP_LOCK_MINUTES: z.coerce.number().int().min(1).default(15),
    TWILIO_ACCOUNT_SID: z.string().optional(),
    TWILIO_AUTH_TOKEN: z.string().optional(),
    TWILIO_FROM_SMS: z.string().optional(),
    TWILIO_FROM_WHATSAPP: z.string().optional(),
  })
  .superRefine((config, ctx) => {
    if (config.NODE_ENV === 'production' && config.ENABLE_DEV_SESSION) {
      ctx.addIssue({
        code: 'custom',
        path: ['ENABLE_DEV_SESSION'],
        message: 'la sesión de desarrollo no puede habilitarse en producción',
      });
    }
    if (config.NODE_ENV === 'production' && config.OTP_PROVIDER === 'fake') {
      ctx.addIssue({
        code: 'custom',
        path: ['OTP_PROVIDER'],
        message: 'el proveedor OTP falso no puede usarse en producción',
      });
    }
    if (config.OTP_PROVIDER === 'twilio') {
      for (const variable of [
        'TWILIO_ACCOUNT_SID',
        'TWILIO_AUTH_TOKEN',
        'TWILIO_FROM_SMS',
        'TWILIO_FROM_WHATSAPP',
      ] as const) {
        if (!config[variable]) {
          ctx.addIssue({
            code: 'custom',
            path: [variable],
            message: 'es obligatoria cuando OTP_PROVIDER=twilio',
          });
        }
      }
    }
  });

export type AppConfig = z.infer<typeof configSchema>;

export const APP_CONFIG = Symbol('APP_CONFIG');

/** Validates the environment at startup: if something is missing the API fails fast, with a reason. */
export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const result = configSchema.safeParse(env);
  if (!result.success) {
    const detail = result.error.issues
      .map((issue) => `${issue.path.join('.')}: ${issue.message}`)
      .join('; ');
    throw new Error(`Configuración inválida: ${detail}`);
  }
  return result.data;
}

/** Loads `.env` only when it exists; variables already set in the environment win. */
export function loadEnvFile(path = '.env'): void {
  if (existsSync(path)) {
    process.loadEnvFile(path);
  }
}
