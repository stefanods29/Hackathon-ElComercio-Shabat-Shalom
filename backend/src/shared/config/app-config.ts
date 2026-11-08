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
    NOTIFICATION_DRIVER: z.enum(['fake', 'fcm']).default('fake'),
    FIREBASE_SERVICE_ACCOUNT_BASE64: z.string().optional(),
    IDEMPOTENCY_RETENTION_HOURS: z.coerce.number().int().min(1).default(168),
    MAX_POSTS_PER_DAY: z.coerce.number().int().min(1).default(10),
    TRUST_PROXY_HOPS: z.coerce.number().int().min(0).default(0),
    OTP_PROVIDER: z.enum(['fake', 'twilio', 'firebase']).default('fake'),
    FIREBASE_PROJECT_ID: z
      .string()
      .regex(/^[a-z0-9-]{6,30}$/, 'debe ser el ID de un proyecto de Firebase')
      .optional(),
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

    JOB_QUEUE_DRIVER: z.enum(['memory', 'pgboss']).default('pgboss'),

    // Phase 2, Lot C · urgent notices with SMS backup (section 7.5). Amounts in US cents.
    SMS_PROVIDER: z.enum(['none', 'fake']).default('fake'),
    URGENT_ACK_TIMEOUT_SECONDS: z.coerce.number().int().min(30).max(3600).default(120),
    SMS_COST_CENTS: z.coerce.number().int().min(0).max(1000).default(5),
    SMS_DAILY_BUDGET_CENTS: z.coerce.number().int().min(0).default(500),
    SMS_MONTHLY_BUDGET_CENTS: z.coerce.number().int().min(0).default(5000),

    // Phase 2, Lot C · operations console (section 9.5).
    CONSOLE_ORIGINS: z
      .string()
      .default('')
      .transform((value) =>
        value
          .split(',')
          .map((origin) => origin.trim())
          .filter((origin) => origin.length > 0),
      )
      .pipe(
        z.array(
          z
            .string()
            .regex(/^https?:\/\/[A-Za-z0-9.-]+(:[0-9]{1,5})?$/, 'debe ser un origen sin ruta'),
        ),
      ),
    CURATION_PUBLISH_DRIVER: z.enum(['disabled', 'filesystem']).default('disabled'),
    CURATION_PUBLIC_ROOT: z.string().min(1).default('../infra/cdn/publico'),
  })
  .superRefine((config, ctx) => {
    if (config.JOB_QUEUE_DRIVER === 'memory' && config.NODE_ENV !== 'test') {
      ctx.addIssue({
        code: 'custom',
        path: ['JOB_QUEUE_DRIVER'],
        message: 'la cola en memoria solo puede usarse en pruebas',
      });
    }
    if (config.NODE_ENV === 'production' && config.NOTIFICATION_DRIVER === 'fake') {
      ctx.addIssue({
        code: 'custom',
        path: ['NOTIFICATION_DRIVER'],
        message: 'fake no puede usarse en producción',
      });
    }
    if (config.NOTIFICATION_DRIVER === 'fcm') {
      try {
        const account: unknown = JSON.parse(
          Buffer.from(config.FIREBASE_SERVICE_ACCOUNT_BASE64 ?? '', 'base64').toString('utf8'),
        );
        z.object({
          project_id: z.string().min(1),
          client_email: z.email(),
          private_key: pemKey,
        }).parse(account);
      } catch {
        ctx.addIssue({
          code: 'custom',
          path: ['FIREBASE_SERVICE_ACCOUNT_BASE64'],
          message: 'se requiere una cuenta de servicio válida para fcm',
        });
      }
    }
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
    if (config.NODE_ENV === 'production' && config.SMS_PROVIDER === 'fake') {
      ctx.addIssue({
        code: 'custom',
        path: ['SMS_PROVIDER'],
        message: 'el proveedor de SMS falso no puede usarse en producción; usa none',
      });
    }
    if (config.SMS_DAILY_BUDGET_CENTS > config.SMS_MONTHLY_BUDGET_CENTS) {
      ctx.addIssue({
        code: 'custom',
        path: ['SMS_DAILY_BUDGET_CENTS'],
        message: 'el tope diario no puede superar al mensual',
      });
    }
    if (
      config.NODE_ENV === 'production' &&
      config.CONSOLE_ORIGINS.some((origin) => !origin.startsWith('https://'))
    ) {
      ctx.addIssue({
        code: 'custom',
        path: ['CONSOLE_ORIGINS'],
        message: 'en producción los orígenes de la consola deben usar https',
      });
    }
    if (config.NODE_ENV === 'production' && config.CURATION_PUBLISH_DRIVER === 'filesystem') {
      ctx.addIssue({
        code: 'custom',
        path: ['CURATION_PUBLISH_DRIVER'],
        message: 'filesystem solo sirve en desarrollo; en producción usa el almacenamiento de la CDN',
      });
    }
    if (config.OTP_PROVIDER === 'firebase' && !config.FIREBASE_PROJECT_ID) {
      ctx.addIssue({
        code: 'custom',
        path: ['FIREBASE_PROJECT_ID'],
        message: 'es obligatoria cuando OTP_PROVIDER=firebase',
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
