import { createHash } from 'node:crypto';
import { isUuidV7 } from '../../src/shared/domain/ids.js';
import {
  durationSeconds,
  loadPlan,
  loadUuid,
  logicalWriteIndex,
  smokeOperation,
  smokeWriteIndex,
} from './model.js';

describe('Plan reproducible de k6', () => {
  it('configura el pico de diez minutos con la mezcla indicada y reconexión con picos', () => {
    const plan = loadPlan({ PROFILE: 'peak' });
    expect(plan).toMatchObject({
      seconds: 600,
      readRate: 1750,
      writeRate: 500,
      reconnectRate: 250,
    });
    expect(plan.options.scenarios?.lecturas).toMatchObject({
      executor: 'constant-arrival-rate',
      duration: '10m',
    });
    expect(plan.options.scenarios?.reconexion).toMatchObject({ executor: 'ramping-arrival-rate' });
    expect(plan.options.thresholds.dropped_iterations).toEqual(['count==0']);
  });

  it('el humo usa 10 VUs durante 30 segundos y conserva proporciones 70/20/10', () => {
    const plan = loadPlan({});
    expect(plan.options).toMatchObject({ vus: 10, duration: '30s' });
    const mix = Array.from({ length: 100 }, (_, index) => smokeOperation(index));
    expect(mix.filter((kind) => kind === 'read')).toHaveLength(70);
    expect(mix.filter((kind) => kind === 'write')).toHaveLength(20);
    expect(mix.filter((kind) => kind === 'reconnect')).toHaveLength(10);
    expect(
      Array.from({ length: 100 }, (_, index) => index)
        .filter((index) => smokeOperation(index) === 'write')
        .map(smokeWriteIndex),
    ).toEqual(Array.from({ length: 20 }, (_, index) => index));
  });

  it('programa exactamente un replay por diez solicitudes sin depender del VU', () => {
    const indices = Array.from({ length: 1000 }, (_, index) => logicalWriteIndex(index));
    expect(new Set(indices).size).toBe(900);
    expect(logicalWriteIndex(8)).toBe(logicalWriteIndex(9));
    const makeId = (index: number) =>
      loadUuid(
        1_799_999_999_000,
        createHash('sha256')
          .update(`run:${logicalWriteIndex(index)}`)
          .digest('hex'),
      );
    expect(makeId(8)).toBe(makeId(9));
    expect(makeId(10)).not.toBe(makeId(9));
    expect(isUuidV7(makeId(0))).toBe(true);
  });

  it('expone umbrales de latencia, error y cola crítica que no se pueden desactivar por accidente', () => {
    const plan = loadPlan({ READ_P95_MS: '123', MAX_ERROR_RATE: '0', MAX_CRITICAL_PENDING: '2' });
    expect(plan.options.thresholds.lecturas_duracion_ms).toEqual(['p(95)<123']);
    expect(plan.options.thresholds.lecturas_errores).toEqual(['rate==0']);
    expect(plan.options.thresholds.cola_critica_pendientes).toEqual(['max<=2']);
    expect(plan.options.thresholds.monitoreo_muestras).toEqual(['count>0']);
  });

  it.each([
    { PROFILE: 'otro' },
    { RATE_SCALE: 'NaN' },
    { MAX_ERROR_RATE: '-1' },
    { READ_P95_MS: '0' },
    { DURATION: '0s' },
    { DURATION: 'infinita' },
  ])('rechaza configuración inválida %j', (env) => {
    expect(() => loadPlan(env)).toThrow();
  });

  it('interpreta duraciones sin depender de k6', () => {
    expect(durationSeconds('30s')).toBe(30);
    expect(durationSeconds('10m')).toBe(600);
  });
});
