/* global __ENV, open */
import http from 'k6/http';
import { check, fail, sleep } from 'k6';
import crypto from 'k6/crypto';
import execution from 'k6/execution';
import { SharedArray } from 'k6/data';
import { Counter, Rate, Trend } from 'k6/metrics';
import { loadPlan, loadUuid, logicalWriteIndex, smokeOperation, smokeWriteIndex } from './model.ts';

const plan = loadPlan(__ENV);
const tokenFile = __ENV.TOKENS_FILE;
if (!tokenFile) throw new Error('Define TOKENS_FILE con el archivo local generado para esta API.');
const users = new SharedArray('load-users', () => JSON.parse(open(tokenFile)).users);
const manifest = new SharedArray('load-manifest', () => {
  const { users: _users, ...metadata } = JSON.parse(open(tokenFile));
  return [metadata];
})[0];
const endpoint = (__ENV.BASE_URL ?? manifest.baseUrl).replace(/\/$/, '');
if (endpoint !== manifest.baseUrl)
  throw new Error('BASE_URL no coincide con el destino del archivo de tokens.');

export const options = plan.options;

const metrics = Object.fromEntries(
  ['lecturas', 'escrituras', 'reconexion'].map((name) => [
    name,
    {
      latency: new Trend(`${name}_duracion_ms`, true),
      errors: new Rate(`${name}_errores`),
      requests: new Counter(`${name}_solicitudes`),
    },
  ]),
);
const monitorErrors = new Rate('monitoreo_errores');
const monitorSamples = new Counter('monitoreo_muestras');
const criticalDepth = new Trend('cola_critica_pendientes');
const criticalAge = new Trend('cola_critica_edad_segundos');
const scheduledReplays = new Counter('reintentos_programados');
const replayed = new Counter('idempotencia_repetida');
const inProgress = new Counter('idempotencia_en_curso');
let lastSample = 0;

function json(response) {
  try {
    return response.json();
  } catch {
    return null;
  }
}
function header(response, key) {
  const entry = Object.entries(response.headers).find(([name]) => name.toLowerCase() === key);
  return entry ? entry[1] : undefined;
}
function requestId(data, suffix) {
  return loadUuid(data.startedAt, crypto.sha256(`${data.runId}:${suffix}`, 'hex'));
}
function params(token, scenario, id) {
  return {
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      'x-request-id': id,
    },
    tags: { name: scenario },
    timeout: '10s',
  };
}
function record(name, response, valid) {
  const accepted = valid && typeof header(response, 'x-request-id') === 'string';
  metrics[name].latency.add(response.timings.duration);
  metrics[name].errors.add(!accepted);
  metrics[name].requests.add(1);
  check(response, { [`${name}: respuesta válida y correlacionada`]: () => accepted });
}

function sample(data) {
  const response = http.get(
    `${endpoint}/v1/operacion/metricas`,
    params(manifest.observerToken, 'monitoreo', requestId(data, `metricas:${Date.now()}`)),
  );
  const snapshot = json(response);
  const valid =
    response.status === 200 && snapshot?.colasMotor === 'pgboss' && Array.isArray(snapshot.colas);
  monitorErrors.add(!valid);
  if (!valid) return;
  monitorSamples.add(1);
  const pending = snapshot.colas.reduce((sum, queue) => sum + queue.criticasPendientes, 0);
  const age = snapshot.colas.reduce(
    (maximum, queue) => Math.max(maximum, queue.edadCriticaMasAntiguaSegundos ?? 0),
    0,
  );
  criticalDepth.add(pending);
  criticalAge.add(age);
  // oxlint-disable-next-line no-console -- Numeric samples are the local time series, without credentials or payloads.
  console.log(
    JSON.stringify({
      evento: 'capacidad.muestra',
      segundos: (Date.now() - data.startedAt) / 1000,
      criticasPendientes: pending,
      edadCriticaSegundos: age,
      outboxPendientes: snapshot.outbox.pendientes,
      idempotencia: snapshot.idempotencia,
    }),
  );
}

export function setup() {
  if (!users.length || manifest.version !== 1) fail('Archivo de tokens inválido.');
  if (Date.parse(manifest.expiresAt) - Date.now() < (plan.seconds + 30) * 1000)
    fail('Los tokens vencen antes de terminar la corrida. Genera un archivo nuevo.');
  if (plan.profile === 'peak') {
    const required = Math.ceil((plan.writeRate * plan.seconds * 0.9) / manifest.maxPostsPerDay);
    if (users.length < required)
      fail(
        `Faltan usuarios sintéticos para respetar el límite diario: se requieren al menos ${required}.`,
      );
  }
  const data = { startedAt: Date.now(), runId: `${manifest.runId}:${Date.now()}` };
  sample(data);
  return data;
}

export function readLoad(data, index = execution.scenario.iterationInTest) {
  const user = users[index % users.length];
  const path =
    index % 4 === 0
      ? '/v1/salud'
      : `/v1/publicaciones?lat=${manifest.location.lat}&lng=${manifest.location.lng}&radio=2000&limite=20`;
  const response = http.get(
    endpoint + path,
    params(user.token, 'lecturas', requestId(data, `lecturas:${index}`)),
  );
  const body = json(response);
  record(
    'lecturas',
    response,
    response.status === 200 &&
      (path === '/v1/salud' ? body?.baseDeDatos === 'ok' : Array.isArray(body?.datos)),
  );
}

export function writeLoad(data, index = execution.scenario.iterationInTest) {
  const logical = logicalWriteIndex(index);
  const user = users[logical % users.length];
  const id = loadUuid(data.startedAt, crypto.sha256(`${data.runId}:publicacion:${logical}`, 'hex'));
  const body = {
    id,
    tipo: 'ofrezco',
    categoria: 'carga',
    titulo: `Prueba sintética de capacidad ${logical}`,
    ubicacion: manifest.location,
    venceEn: new Date(data.startedAt + 3600000).toISOString(),
  };
  const config = params(user.token, 'escrituras', requestId(data, `escrituras:${index}`));
  config.headers['Idempotency-Key'] = id;
  config.responseCallback = http.expectedStatuses(200, 201, 409);
  const response = http.post(`${endpoint}/v1/publicaciones`, JSON.stringify(body), config);
  const result = json(response);
  const busy =
    response.status === 409 &&
    result?.codigo === 'solicitud_en_curso' &&
    Number(header(response, 'retry-after')) > 0;
  const valid = ([200, 201].includes(response.status) && result?.id === id) || busy;
  if (index % 10 === 9) scheduledReplays.add(1);
  if (header(response, 'idempotent-replayed') === 'true') replayed.add(1);
  if (busy) inProgress.add(1);
  record('escrituras', response, valid);
}

export function reconnectLoad(data, index = execution.scenario.iterationInTest) {
  sleep(Math.random() * 0.2);
  const response = http.get(
    `${endpoint}/v1/sync/credenciales`,
    params(users[index % users.length].token, 'reconexion', requestId(data, `reconexion:${index}`)),
  );
  const body = json(response);
  record(
    'reconexion',
    response,
    response.status === 200 &&
      typeof body?.token === 'string' &&
      typeof body?.expiraEn === 'string',
  );
}

export function observeLoad(data) {
  sample(data);
  sleep(1);
}

export default function smoke(data) {
  const index = execution.scenario.iterationInTest;
  const operation = smokeOperation(index);
  if (operation === 'read') readLoad(data, index);
  else if (operation === 'write') writeLoad(data, smokeWriteIndex(index));
  else reconnectLoad(data, index);
  if (execution.vu.idInTest === 1 && Date.now() - lastSample >= 1000) {
    sample(data);
    lastSample = Date.now();
  }
  sleep(0.1);
}

export function teardown(data) {
  sample(data);
}

export function handleSummary(data) {
  const count = (name) => data.metrics[name]?.values.count ?? 0;
  const report = {
    perfil: plan.profile,
    duracionConfiguradaSegundos: plan.seconds,
    objetivo:
      plan.profile === 'peak'
        ? {
            lecturasPorSegundo: plan.readRate,
            escriturasPorSegundo: plan.writeRate,
            reconexionBasePorSegundo: plan.reconnectRate,
          }
        : { vus: 10 },
    escenarios: Object.fromEntries(
      ['lecturas', 'escrituras', 'reconexion'].map((name) => [
        name,
        {
          solicitudes: count(`${name}_solicitudes`),
          p95Ms: data.metrics[`${name}_duracion_ms`]?.values['p(95)'] ?? null,
          tasaError: data.metrics[`${name}_errores`]?.values.rate ?? null,
        },
      ]),
    ),
    criticas: {
      maxPendientes: data.metrics.cola_critica_pendientes?.values.max ?? null,
      maxEdadSegundos: data.metrics.cola_critica_edad_segundos?.values.max ?? null,
      muestras: count('monitoreo_muestras'),
    },
    idempotencia: {
      reintentosProgramados: count('reintentos_programados'),
      repetidas: count('idempotencia_repetida'),
      enCurso: count('idempotencia_en_curso'),
    },
    iteracionesNoIniciadas: count('dropped_iterations'),
    umbrales: Object.fromEntries(
      Object.entries(data.metrics)
        .filter(([, value]) => value.thresholds)
        .map(([name, value]) => [name, value.thresholds]),
    ),
  };
  return {
    stdout: JSON.stringify(report, null, 2) + '\n',
    [__ENV.SUMMARY_PATH ?? 'capacity.load-summary.json']: JSON.stringify(report, null, 2),
  };
}
