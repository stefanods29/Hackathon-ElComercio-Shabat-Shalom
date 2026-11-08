import { syncTelemetrySchema, utcDay } from './sync-telemetry.js';

const valid = {
  versionApp: '0.1.0+1',
  sistema: 'android',
  periodoInicio: '2026-11-07T09:00:00.000Z',
  periodoFin: '2026-11-08T09:30:00.000Z',
  colaPendientes: 2,
  enviosConfirmados: 3,
  tiempoHastaEnviadoP50Segundos: 20,
  tiempoHastaEnviadoP95Segundos: 90,
  rechazosPermanentes: { resena_duplicada: 1 },
  segundosDesdeUltimaSincronizacion: 45,
  erroresDeConexion: 4,
};

describe('Contrato de la telemetría de sincronización', () => {
  it('acepta los contadores del contrato', () => {
    expect(syncTelemetrySchema.safeParse(valid).success).toBe(true);
    expect(
      syncTelemetrySchema.safeParse({
        ...valid,
        enviosConfirmados: 0,
        tiempoHastaEnviadoP50Segundos: null,
        tiempoHastaEnviadoP95Segundos: null,
        rechazosPermanentes: {},
        segundosDesdeUltimaSincronizacion: null,
      }).success,
    ).toBe(true);
  });

  it('rechaza cualquier campo fuera del contrato, como un teléfono o un id', () => {
    for (const extra of [
      { telefono: '+51900000009' },
      { vecinoId: '01970000-0000-7000-8000-0000000000b1' },
      { dispositivo: 'pixel-8' },
      { ubicacion: { lat: -12.08, lng: -77.03 } },
    ]) {
      expect(syncTelemetrySchema.safeParse({ ...valid, ...extra }).success).toBe(false);
    }
  });

  it('rechaza contadores negativos, períodos al revés y percentiles incoherentes', () => {
    for (const invalid of [
      { colaPendientes: -1 },
      { enviosConfirmados: 1.5 },
      { sistema: 'windows' },
      { versionApp: 'versión con espacios' },
      { periodoFin: '2026-11-06T00:00:00.000Z' },
      { tiempoHastaEnviadoP50Segundos: 100, tiempoHastaEnviadoP95Segundos: 90 },
      { rechazosPermanentes: { 'Código Con Espacios': 1 } },
      { rechazosPermanentes: { resena_duplicada: 0 } },
      {
        rechazosPermanentes: Object.fromEntries(
          Array.from({ length: 21 }, (_, index) => [`codigo_${index}`, 1]),
        ),
      },
    ]) {
      expect(syncTelemetrySchema.safeParse({ ...valid, ...invalid }).success).toBe(false);
    }
  });

  it('guarda solo el día UTC de recepción', () => {
    expect(utcDay(new Date('2026-11-08T23:59:59.999Z'))).toBe('2026-11-08');
    expect(utcDay(new Date('2026-11-08T21:00:00-05:00'))).toBe('2026-11-09');
  });
});
