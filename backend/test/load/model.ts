export type LoadEnvironment = Readonly<Record<string, string | undefined>>;

interface LoadOptions {
  thresholds: Record<string, string[]>;
  summaryTrendStats: string[];
  summaryTimeUnit: string;
  systemTags: string[];
  vus?: number;
  duration?: string;
  scenarios?: Record<string, unknown>;
}

export function numericOption(
  env: LoadEnvironment,
  key: string,
  fallback: number,
  min: number,
  max: number,
): number {
  const value = env[key] === undefined ? fallback : Number(env[key]);
  if (!Number.isFinite(value) || value < min || value > max)
    throw new Error(`Opción inválida: ${key}`);
  return value;
}

export function durationSeconds(value: string): number {
  const match = /^(\d+)(s|m|h)$/.exec(value);
  if (!match) throw new Error('DURATION debe usar segundos, minutos u horas enteros.');
  const seconds = Number(match[1]) * ({ s: 1, m: 60, h: 3600 }[match[2]!] ?? 0);
  if (seconds < 1 || seconds > 3600) throw new Error('DURATION debe estar entre 1 s y 1 h.');
  return seconds;
}

export function logicalWriteIndex(index: number): number {
  return Math.floor(index / 10) * 9 + Math.min(index % 10, 8);
}

export function smokeOperation(index: number): 'read' | 'write' | 'reconnect' {
  return index % 20 < 14 ? 'read' : index % 20 < 18 ? 'write' : 'reconnect';
}

export function smokeWriteIndex(index: number): number {
  return Math.floor(index / 20) * 4 + (index % 20) - 14;
}

/** Stable UUIDv7 for a logical operation: its replay uses the same id across VUs. */
export function loadUuid(timestamp: number, hash: string): string {
  const time = timestamp.toString(16).padStart(12, '0');
  const variant = ((Number.parseInt(hash.slice(16, 18), 16) & 63) | 128).toString(16);
  return `${time.slice(0, 8)}-${time.slice(8)}-7${hash.slice(13, 16)}-${variant}${hash.slice(18, 20)}-${hash.slice(20, 32)}`;
}

export function loadPlan(env: LoadEnvironment) {
  const profile = env.PROFILE ?? 'smoke';
  if (!['smoke', 'peak'].includes(profile)) throw new Error('PROFILE debe ser smoke o peak.');
  const duration = env.DURATION ?? (profile === 'peak' ? '10m' : '30s');
  const seconds = durationSeconds(duration);
  const scale = numericOption(env, 'RATE_SCALE', 1, 0.001, 1);
  const maxErrorRate = numericOption(env, 'MAX_ERROR_RATE', 0.01, 0, 1);
  const criticalLimit = numericOption(env, 'MAX_CRITICAL_PENDING', 100, 0, 1_000_000);
  const criticalAge = numericOption(env, 'MAX_CRITICAL_AGE_SECONDS', 30, 0.001, 3600);
  const latency = {
    lecturas: numericOption(env, 'READ_P95_MS', 300, 0.000001, 60_000),
    escrituras: numericOption(env, 'WRITE_P95_MS', 500, 0.000001, 60_000),
    reconexion: numericOption(env, 'RECONNECT_P95_MS', 300, 0.000001, 60_000),
  };
  const thresholds: Record<string, string[]> = {
    http_req_failed: [maxErrorRate === 0 ? 'rate==0' : `rate<${maxErrorRate}`],
    monitoreo_errores: ['rate==0'],
    monitoreo_muestras: ['count>0'],
    cola_critica_pendientes: [`max<=${criticalLimit}`],
    cola_critica_edad_segundos: [`max<${criticalAge}`],
  };
  for (const [name, limit] of Object.entries(latency)) {
    thresholds[`${name}_duracion_ms`] = [`p(95)<${limit}`];
    thresholds[`${name}_errores`] = [maxErrorRate === 0 ? 'rate==0' : `rate<${maxErrorRate}`];
    thresholds[`${name}_solicitudes`] = ['count>0'];
  }
  const common = {
    thresholds,
    summaryTrendStats: ['avg', 'med', 'p(95)', 'p(99)', 'min', 'max'],
    summaryTimeUnit: 'ms',
    systemTags: ['status', 'method', 'name', 'scenario', 'expected_response'],
  };
  const readRate = Math.max(1, Math.round(1750 * scale));
  const writeRate = Math.max(1, Math.round(500 * scale));
  const reconnectRate = Math.max(1, Math.round(250 * scale));
  const options: LoadOptions =
    profile === 'smoke'
      ? { ...common, vus: 10, duration }
      : {
          ...common,
          thresholds: { ...thresholds, dropped_iterations: ['count==0'] },
          scenarios: {
            lecturas: {
              executor: 'constant-arrival-rate',
              exec: 'readLoad',
              rate: readRate,
              timeUnit: '1s',
              duration,
              preAllocatedVUs: Math.max(10, Math.ceil(600 * scale)),
              maxVUs: Math.max(20, Math.ceil(1800 * scale)),
              gracefulStop: '5s',
            },
            escrituras: {
              executor: 'constant-arrival-rate',
              exec: 'writeLoad',
              rate: writeRate,
              timeUnit: '1s',
              duration,
              preAllocatedVUs: Math.max(10, Math.ceil(350 * scale)),
              maxVUs: Math.max(20, Math.ceil(800 * scale)),
              gracefulStop: '5s',
            },
            reconexion: {
              executor: 'ramping-arrival-rate',
              exec: 'reconnectLoad',
              startRate: reconnectRate,
              timeUnit: '1s',
              stages: [0.2, 0.05, 0.05, 0.2, 0.05, 0.05, 0.4].map((fraction, index) => ({
                duration: `${seconds * fraction}s`,
                target: [1, 4].includes(index) ? reconnectRate * 2 : reconnectRate,
              })),
              preAllocatedVUs: Math.max(10, Math.ceil(300 * scale)),
              maxVUs: Math.max(20, Math.ceil(600 * scale)),
              gracefulStop: '5s',
            },
            monitoreo: {
              executor: 'constant-vus',
              exec: 'observeLoad',
              vus: 1,
              duration,
              gracefulStop: '5s',
            },
          },
        };
  return {
    profile,
    seconds,
    readRate,
    writeRate,
    reconnectRate,
    latency,
    maxErrorRate,
    criticalLimit,
    criticalAge,
    options,
  };
}
