import { spawn, execFileSync, type ChildProcess } from 'node:child_process';
import { generateKeyPairSync, randomBytes } from 'node:crypto';
import { closeSync, openSync } from 'node:fs';
import { mkdtemp, readFile, stat, unlink, writeFile } from 'node:fs/promises';
import { createServer } from 'node:net';
import { cpus, platform, arch, totalmem, tmpdir } from 'node:os';
import path from 'node:path';
import { setTimeout as delay } from 'node:timers/promises';
import { parseArgs } from 'node:util';
import { sql } from 'kysely';
import { seed, PILOT_ZONE } from './seed-data.js';
import { generateLoadFixture } from './load-fixture.js';
import { loadConfig } from '../src/shared/config/app-config.js';
import { createKysely } from '../src/shared/db/connection.js';
import { migrateToLatest } from '../src/shared/db/migrator.js';
import { PgBossJobQueue } from '../src/shared/queues/job-queue.pgboss.js';
import { durationSeconds } from '../test/load/model.js';

interface LoadSummary {
  perfil: string;
  escenarios: Record<
    string,
    { solicitudes: number; p95Ms: number | null; tasaError: number | null }
  >;
  criticas: { maxPendientes: number; maxEdadSegundos: number; muestras: number };
  umbrales: Record<string, Record<string, { ok: boolean }>>;
}
interface MetricSample {
  segundos: number;
  criticasPendientes: number;
  edadCriticaSegundos: number;
  outboxPendientes: number;
}
interface ManagedProcess {
  child: ChildProcess;
  done: Promise<number>;
}

const { values } = parseArgs({
  options: {
    duration: { type: 'string', default: '30s' },
    'verify-threshold-failure': { type: 'boolean', default: false },
    report: { type: 'string' },
  },
});
const seconds = durationSeconds(values.duration);
const adminUrl = process.env.DATABASE_URL_ADMIN;
if (!adminUrl)
  throw new Error('Define DATABASE_URL_ADMIN: el humo crea y elimina una base aislada.');
const directory = await mkdtemp(path.join(tmpdir(), 'vecinal-capacidad-'));
const backend = process.cwd();
const tokenPath = path.join(directory, 'smoke.load-tokens.json');
const summaryPath = path.join(directory, 'smoke.load-summary.json');
const samplePath = path.join(directory, 'muestras.jsonl');
const apiLogPath = path.join(directory, 'api.jsonl');
const workerLogPath = path.join(directory, 'workers.jsonl');
const databaseName = `vecinal_carga_${process.pid}_${randomBytes(4).toString('hex')}`;
const databaseUrl = new URL(adminUrl);
databaseUrl.pathname = '/' + databaseName;
const admin = createKysely(adminUrl, 1);
const db = createKysely(databaseUrl.toString(), 2);
const processes: ManagedProcess[] = [];
let created = false;
let probe: PgBossJobQueue | undefined;
let producer: ReturnType<typeof setInterval> | undefined;
const producing = new Set<Promise<void>>();
let completedProbes = 0;
let failedProbes = 0;
let interrupted = false;

function start(
  command: string,
  args: string[],
  env: NodeJS.ProcessEnv,
  logPath: string,
): ManagedProcess {
  const descriptor = openSync(logPath, 'w', 0o600);
  const child = spawn(command, args, {
    cwd: backend,
    env: command === 'k6' ? { ...env, K6_NO_USAGE_REPORT: 'true' } : env,
    stdio: ['ignore', descriptor, descriptor],
  });
  let closed = false;
  const close = () => {
    if (!closed) {
      closed = true;
      closeSync(descriptor);
    }
  };
  const done = new Promise<number>((resolve, reject) => {
    child.once('error', (error) => {
      close();
      reject(error);
    });
    child.once('exit', (code) => {
      close();
      resolve(code ?? 1);
    });
  });
  void done.catch(() => {});
  const managed = { child, done };
  processes.push(managed);
  return managed;
}

async function ready(predicate: () => Promise<boolean>, child: ChildProcess): Promise<void> {
  const deadline = Date.now() + 20_000;
  while (Date.now() < deadline) {
    if (interrupted || child.exitCode !== null || child.signalCode !== null)
      throw new Error('El proceso local se detuvo antes de iniciar.');
    if (await predicate()) return;
    await delay(100);
  }
  throw new Error('No arrancó el proceso local; revisa sus logs en el directorio de evidencia.');
}

async function freePort(): Promise<number> {
  const server = createServer();
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address();
  if (!address || typeof address === 'string')
    throw new Error('No se pudo reservar un puerto local.');
  await new Promise<void>((resolve, reject) =>
    server.close((error) => (error ? reject(error) : resolve())),
  );
  return address.port;
}

async function stop(process: ManagedProcess): Promise<void> {
  if (process.child.exitCode !== null || process.child.signalCode !== null) return;
  process.child.kill('SIGTERM');
  await Promise.race([process.done, delay(15_000)]);
  if (process.child.exitCode === null && process.child.signalCode === null) {
    process.child.kill('SIGKILL');
    await process.done;
  }
}

const signal = () => {
  interrupted = true;
  for (const process of processes) process.child.kill('SIGTERM');
};
process.once('SIGINT', signal);
process.once('SIGTERM', signal);

try {
  await sql`CREATE DATABASE ${sql.id(databaseName)}`.execute(admin);
  created = true;
  await migrateToLatest(db);
  await seed(db);
  const port = await freePort();
  const baseUrl = `http://127.0.0.1:${port}`;
  const pem = generateKeyPairSync('ec', { namedCurve: 'prime256v1' })
    .privateKey.export({ type: 'pkcs8', format: 'pem' })
    .toString();
  const environment: NodeJS.ProcessEnv = {
    ...process.env,
    NODE_ENV: 'development',
    PORT: String(port),
    DATABASE_URL: databaseUrl.toString(),
    JWT_PRIVATE_KEY_PEM: pem,
    JWT_ISSUER: 'capacidad-local',
    JWT_KID: 'capacidad-local',
    JWT_ACCESS_MINUTES: '15',
    POWERSYNC_URL: 'http://localhost:8080',
    ENABLE_DEV_SESSION: 'false',
    JOB_QUEUE_DRIVER: 'pgboss',
    OTP_PROVIDER: 'fake',
    OTP_HASH_SECRET: randomBytes(32).toString('hex'),
    REFRESH_TOKEN_SECRET: randomBytes(32).toString('hex'),
    TRUST_PROXY_HOPS: '0',
    MAX_POSTS_PER_DAY: '10',
  };
  const config = loadConfig(environment);
  await generateLoadFixture(db, config, {
    count: 100,
    zoneId: PILOT_ZONE.id,
    baseUrl,
    output: tokenPath,
    location: { lat: -12.086, lng: -77.035 },
  });
  if (((await stat(tokenPath)).mode & 0o777) !== 0o600)
    throw new Error('El archivo de tokens no tiene permisos 0600.');
  const bundle = JSON.parse(await readFile(tokenPath, 'utf8')) as {
    observerToken: string;
    users: Array<{ token: string }>;
  };
  const api = start(process.execPath, ['dist/main.js'], environment, apiLogPath);
  await ready(async () => {
    try {
      const response = await fetch(baseUrl + '/v1/salud');
      await response.arrayBuffer();
      return response.status === 200;
    } catch {
      return false;
    }
  }, api.child);
  const workers = start(process.execPath, ['dist/workers/main.js'], environment, workerLogPath);
  await ready(
    async () => (await readFile(workerLogPath, 'utf8')).includes('workers.iniciados'),
    workers.child,
  );
  probe = new PgBossJobQueue(config, { worker: true, pollingIntervalSeconds: 0.5 });
  await probe.onModuleInit();
  await probe.process('capacidad.sonda_critica', async () => {
    await delay(50);
    completedProbes += 1;
  });
  const enqueueProbe = () => {
    const pending = probe!
      .enqueue('capacidad.sonda_critica', { tipo: 'sonda_sintetica' }, { priority: 'critical' })
      .catch(() => {
        failedProbes += 1;
      })
      .finally(() => producing.delete(pending));
    producing.add(pending);
  };
  enqueueProbe();
  producer = setInterval(enqueueProbe, 1000);
  const k6Environment = {
    ...environment,
    PROFILE: 'smoke',
    DURATION: values.duration,
    BASE_URL: baseUrl,
    TOKENS_FILE: tokenPath,
    SUMMARY_PATH: summaryPath,
  };
  const run = start(
    'k6',
    [
      'run',
      '--vus',
      '10',
      '--duration',
      values.duration,
      '--log-format=json',
      '--console-output=' + samplePath,
      'test/load/emergency-peak.js',
    ],
    k6Environment,
    path.join(directory, 'k6.log'),
  );
  const code = await run.done;
  if (code !== 0)
    throw new Error(`k6 rechazó el humo (salida ${code}); revisa k6.log en ${directory}.`);
  const summary = JSON.parse(await readFile(summaryPath, 'utf8')) as LoadSummary;
  if (
    Object.values(summary.escenarios).some((scenario) => scenario.solicitudes === 0) ||
    Object.keys(summary.umbrales).length < 13
  )
    throw new Error('La corrida no ejercitó los tres escenarios y sus umbrales.');
  const snapshotResponse = await fetch(baseUrl + '/v1/operacion/metricas', {
    headers: { Authorization: 'Bearer ' + bundle.observerToken },
  });
  if (!snapshotResponse.ok) throw new Error('No se pudo leer la instantánea administrativa final.');
  const snapshot: unknown = await snapshotResponse.json();
  const samples: MetricSample[] = [];
  for (const line of (await readFile(samplePath, 'utf8')).split('\n').filter(Boolean)) {
    try {
      const record = JSON.parse(line) as { msg?: string; message?: string };
      const entry = JSON.parse(record.msg ?? record.message ?? line) as {
        evento?: string;
      } & MetricSample;
      if (entry.evento === 'capacidad.muestra')
        samples.push({
          segundos: entry.segundos,
          criticasPendientes: entry.criticasPendientes,
          edadCriticaSegundos: entry.edadCriticaSegundos,
          outboxPendientes: entry.outboxPendientes,
        });
    } catch {
      /* Non-sample diagnostics are left in the private raw log. */
    }
  }
  if (
    samples.length < Math.max(2, Math.floor(seconds / 5)) ||
    completedProbes < 1 ||
    failedProbes > 0
  )
    throw new Error('No hay evidencia suficiente de monitoreo o de la sonda crítica.');
  let negativeCheck: {
    salida: number;
    latenciaRechazada: boolean;
    salidaCola: number;
    colaRechazada: boolean;
  } | null = null;
  if (values['verify-threshold-failure']) {
    const negativePath = path.join(directory, 'negative.load-summary.json');
    const negative = start(
      'k6',
      [
        'run',
        '--vus',
        '10',
        '--duration',
        '2s',
        '--log-format=json',
        'test/load/emergency-peak.js',
      ],
      {
        ...k6Environment,
        DURATION: '2s',
        READ_P95_MS: '0.000001',
        WRITE_P95_MS: '0.000001',
        RECONNECT_P95_MS: '0.000001',
        SUMMARY_PATH: negativePath,
      },
      path.join(directory, 'negative.log'),
    );
    const negativeCode = await negative.done;
    const result = JSON.parse(await readFile(negativePath, 'utf8')) as LoadSummary;
    const rejected = Object.entries(result.umbrales).some(
      ([name, thresholds]) =>
        name.endsWith('_duracion_ms') &&
        Object.values(thresholds).some((threshold) => !threshold.ok),
    );
    if (
      negativeCode === 0 ||
      !rejected ||
      Object.values(result.escenarios).some((scenario) => scenario.solicitudes === 0)
    )
      throw new Error('El control negativo no demostró rechazo por latencia.');
    await probe.boss.offWork('capacidad.sonda_critica');
    await probe.enqueue(
      'capacidad.sonda_critica',
      { tipo: 'sonda_sintetica' },
      { priority: 'critical' },
    );
    const queuePath = path.join(directory, 'negative-queue.load-summary.json');
    const negativeQueue = start(
      'k6',
      [
        'run',
        '--vus',
        '10',
        '--duration',
        '2s',
        '--log-format=json',
        'test/load/emergency-peak.js',
      ],
      { ...k6Environment, DURATION: '2s', MAX_CRITICAL_PENDING: '0', SUMMARY_PATH: queuePath },
      path.join(directory, 'negative-queue.log'),
    );
    const queueCode = await negativeQueue.done;
    const queueResult = JSON.parse(await readFile(queuePath, 'utf8')) as LoadSummary;
    const queueRejected = Object.values(queueResult.umbrales.cola_critica_pendientes ?? {}).some(
      (threshold) => !threshold.ok,
    );
    if (queueCode === 0 || !queueRejected)
      throw new Error('El control negativo no rechazó la cola crítica detenida.');
    negativeCheck = {
      salida: negativeCode,
      latenciaRechazada: rejected,
      salidaCola: queueCode,
      colaRechazada: queueRejected,
    };
  }
  const apiLog = await readFile(apiLogPath, 'utf8');
  const entries = apiLog
    .split('\n')
    .filter(Boolean)
    .flatMap((line) => {
      try {
        return [JSON.parse(line) as { message?: { evento?: string; requestId?: string } }];
      } catch {
        return [];
      }
    });
  const correlated = entries.filter(
    (entry) =>
      entry.message?.evento === 'http.solicitud_completada' &&
      typeof entry.message.requestId === 'string',
  ).length;
  if (
    correlated === 0 ||
    apiLog.includes(bundle.users[0]!.token) ||
    apiLog.includes(bundle.observerToken) ||
    apiLog.includes(config.OTP_HASH_SECRET) ||
    apiLog.includes('BEGIN PRIVATE KEY')
  )
    throw new Error('Falló la comprobación de correlación o privacidad de logs.');
  const report = {
    fecha: new Date().toISOString(),
    commit: execFileSync('git', ['rev-parse', 'HEAD'], { cwd: backend, encoding: 'utf8' }).trim(),
    arbolLimpio:
      execFileSync('git', ['status', '--porcelain'], { cwd: backend, encoding: 'utf8' }).trim() ===
      '',
    entorno: {
      sistema: platform(),
      arquitectura: arch(),
      cpu: cpus()[0]?.model,
      nucleosLogicos: cpus().length,
      memoriaGiB: Math.round(totalmem() / 2 ** 30),
      node: process.version,
      k6: execFileSync('k6', ['version'], { encoding: 'utf8' }).trim(),
      postgres: (
        await sql<{ version: string }>`SELECT current_setting('server_version') AS version`.execute(
          db,
        )
      ).rows[0]?.version,
      postgis: (await sql<{ version: string }>`SELECT postgis_lib_version() AS version`.execute(db))
        .rows[0]?.version,
    },
    duracionSegundos: seconds,
    usuariosSinteticos: 100,
    apiYWorkersSeparados: true,
    sesionDeDesarrollo: false,
    resumen: summary,
    muestras: samples,
    instantaneaFinal: snapshot,
    logsCorrelacionados: correlated,
    sondasCriticasProcesadas: completedProbes,
    controlNegativo: negativeCheck,
    alcance:
      'Humo local; no certifica 2500 solicitudes/s ni sustituye la prueba completa en staging.',
  };
  const reportPath = path.join(directory, 'report.json');
  await writeFile(reportPath, JSON.stringify(report, null, 2), { mode: 0o600 });
  if (values.report)
    await writeFile(values.report, JSON.stringify(report, null, 2), { mode: 0o600 });
  console.log(
    JSON.stringify({
      evento: 'capacidad.humo_verificado',
      informe: reportPath,
      logsCorrelacionados: correlated,
      sondasCriticasProcesadas: completedProbes,
    }),
  );
} finally {
  if (producer) clearInterval(producer);
  await Promise.allSettled(producing);
  await Promise.allSettled([probe?.beforeApplicationShutdown(), ...processes.map(stop)]);
  await unlink(tokenPath).catch(() => {});
  await db.destroy();
  try {
    if (created) await sql`DROP DATABASE ${sql.id(databaseName)} WITH (FORCE)`.execute(admin);
  } finally {
    await admin.destroy();
  }
  process.off('SIGINT', signal);
  process.off('SIGTERM', signal);
}
