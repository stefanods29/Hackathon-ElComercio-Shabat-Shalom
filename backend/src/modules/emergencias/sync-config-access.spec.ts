import { readFileSync } from 'node:fs';
import {
  DEFAULT_HYDRATION_STATE,
  parseSyncConfig,
  RequestJwtPayload,
  RequestParameters,
  type RequestedStream,
} from '@powersync/service-sync-rules';
import { describe, expect, it } from 'vitest';

const yaml = readFileSync(
  new URL('../../../../infra/powersync/sync-config.yaml', import.meta.url),
  'utf8',
);
const { config } = parseSyncConfig(yaml, { defaultSchema: 'public' });
const rules = config.hydrate({ hydrationState: DEFAULT_HYDRATION_STATE, sqlite: null });
const table = (name: string) => ({ connectionTag: 'default', schema: 'emergencias', name });
const cases = table('pedidos_ayuda');
const assignments = table('asignaciones');
const history = table('historial_para_autor');
const details = table('ubicaciones_en_camino');
const access = table('autorizaciones_stream');

const summary = 'caso_asignado';
const exact = 'caso_ubicacion_exacta';
const endedAt = '2026-11-08T06:00:00Z';
const privateDetail = { descripcion: 'Detalle ficticio', lat: -12.01342, lng: -77.01342 };

type DeliveryOptions = {
  stream?: typeof summary | typeof exact | null;
  authorization?: string | null;
  user?: string;
  session?: string | null;
  roles?: string[];
  state?: string;
  closedAt?: string | null;
  revokedAt?: string | null;
  ended?: boolean;
};

async function delivered({
  stream = summary,
  authorization = 'permiso-resumen',
  user = 'ana',
  session = 'sesion-ana',
  roles = ['brigadista'],
  state = 'visto',
  closedAt = null,
  revokedAt = null,
  ended = false,
}: DeliveryOptions = {}) {
  const record = {
    id: 'pedido-a',
    necesidad: 'agua',
    prioridad: 'alta',
    estado: state,
    version: 4,
    celda: 'celda-aproximada',
    creado_en: '2026-11-08T04:00:00Z',
    vence_en: '2026-11-08T08:00:00Z',
    cerrado_en: closedAt,
    detalle: 'Detalle heredado',
  };
  const rows = [
    ...rules.evaluateRow({ sourceTable: cases, record }),
    ...rules.evaluateRow({ sourceTable: cases, record: { ...record, id: 'pedido-ajeno' } }),
    ...rules.evaluateRow({
      sourceTable: details,
      record: { pedido_id: 'pedido-a', ...privateDetail },
    }),
    ...rules.evaluateRow({
      sourceTable: details,
      record: { pedido_id: 'pedido-ajeno', ...privateDetail },
    }),
  ];
  const parameterRows = [
    ...rules.evaluateParameterRow(cases, record),
    ...rules.evaluateParameterRow(cases, { ...record, id: 'pedido-ajeno' }),
    ...rules.evaluateParameterRow(assignments, {
      id: 'asignacion-ana',
      pedido_id: 'pedido-a',
      usuario_id: 'ana',
      finalizada_en: ended ? endedAt : null,
    }),
    ...rules.evaluateParameterRow(assignments, {
      id: 'asignacion-beto',
      pedido_id: 'pedido-a',
      usuario_id: 'beto',
      finalizada_en: ended ? null : endedAt,
    }),
    ...['resumen', 'exacta'].flatMap((scope) =>
      rules.evaluateParameterRow(access, {
        id: `permiso-${scope}`,
        asignacion_id: 'asignacion-ana',
        sesion_id: 'sesion-ana',
        alcance: scope,
        revocada_en: revokedAt,
      }),
    ),
    ...rules.evaluateParameterRow(access, {
      id: 'permiso-nuevo',
      asignacion_id: 'asignacion-beto',
      sesion_id: 'sesion-beto',
      alcance: 'resumen',
      revocada_en: null,
    }),
  ];
  const streams: Record<string, RequestedStream[]> = stream
    ? {
        [stream]: [
          {
            opaque_id: 0,
            priorityOverride: null,
            parameters: { pedido_id: 'pedido-a', autorizacion_id: authorization },
          },
        ],
      }
    : {};
  const { querier, errors } = rules.getBucketParameterQuerier({
    globalParameters: new RequestParameters(
      new RequestJwtPayload({ sub: user, sid: session, roles }),
      {},
    ),
    hasDefaultStreams: true,
    streams,
  });
  expect(errors).toEqual([]);
  const dynamic = await querier.queryDynamicBucketDescriptions({
    async getParameterSets(lookups) {
      return lookups.map((lookup) => ({
        lookup,
        rows: parameterRows
          .filter(
            (entry) => entry.lookup.serializedRepresentation === lookup.serializedRepresentation,
          )
          .flatMap((entry) => entry.bucketParameters),
      }));
    },
  });
  const buckets = new Set([...querier.staticBuckets, ...dynamic].map((bucket) => bucket.bucket));
  return rows
    .filter((row) => buckets.has(row.bucket))
    .map(({ table: destination, data }) => ({ destination, data }));
}

describe('acceso a pedidos por Sync Streams', () => {
  it('reserva todas las tablas privadas de Emergencias para streams explícitos', async () => {
    const emergencySources = config.bucketSources.filter((stream) =>
      stream.dataSources.some((source) =>
        [cases, assignments, history, details, access].some((entry) =>
          source.tableSyncsData(entry),
        ),
      ),
    );
    expect(emergencySources.map((stream) => stream.name)).toEqual([summary, exact, 'mi_pedido']);
    expect(emergencySources.every((stream) => !stream.subscribedToByDefault)).toBe(true);
    expect(
      emergencySources
        .filter((stream) => stream.dataSources.some((source) => source.tableSyncsData(details)))
        .map((stream) => stream.name),
    ).toEqual([exact]);
    expect(
      emergencySources.some((stream) =>
        stream.dataSources.some((source) => source.tableSyncsData(access)),
      ),
    ).toBe(false);
    expect(await delivered({ stream: null })).toEqual([]);
  });

  it('el resumen solo devuelve el pedido asignado y la celda aproximada', async () => {
    expect(await delivered()).toEqual([
      {
        destination: 'pedidos_ayuda',
        data: {
          id: 'pedido-a',
          necesidad: 'agua',
          prioridad: 'alta',
          estado: 'visto',
          version: 4,
          celda: 'celda-aproximada',
          creado_en: '2026-11-08T04:00:00Z',
          vence_en: '2026-11-08T08:00:00Z',
        },
      },
    ]);
    expect(await delivered({ state: 'atendido' })).toEqual([]);
    expect(await delivered({ closedAt: endedAt })).toEqual([]);
  });

  it('bloquea aperturas directas y permisos de otra cuenta, sesión o alcance', async () => {
    expect(await delivered({ authorization: null })).toEqual([]);
    expect(await delivered({ authorization: 'inventado' })).toEqual([]);
    expect(await delivered({ user: 'beto' })).toEqual([]);
    expect(await delivered({ session: 'otro-celular' })).toEqual([]);
    expect(await delivered({ session: null })).toEqual([]);
    expect(await delivered({ roles: [] })).toEqual([]);
    expect(await delivered({ authorization: 'permiso-exacta' })).toEqual([]);
    expect(await delivered({ stream: exact, state: 'en_camino' })).toEqual([]);
    expect(await delivered({ revokedAt: endedAt })).toEqual([]);
  });

  it('el permiso exacto solo entrega detalle mientras el pedido está en camino y abierto', async () => {
    const options = { stream: exact, authorization: 'permiso-exacta' } as const;
    expect(await delivered(options)).toEqual([]);
    expect(await delivered({ ...options, state: 'en_camino' })).toEqual([
      { destination: 'ubicaciones_casos', data: { id: 'pedido-a', ...privateDetail } },
    ]);
    expect(await delivered({ ...options, state: 'atendido' })).toEqual([]);
    expect(await delivered({ ...options, state: 'en_camino', closedAt: endedAt })).toEqual([]);
  });

  it('al reasignar se retiran los dos streams del operador anterior', async () => {
    expect(await delivered({ ended: true })).toEqual([]);
    expect(
      await delivered({
        ended: true,
        stream: exact,
        authorization: 'permiso-exacta',
        state: 'en_camino',
      }),
    ).toEqual([]);
    const next = await delivered({
      ended: true,
      user: 'beto',
      session: 'sesion-beto',
      authorization: 'permiso-nuevo',
    });
    expect(next.map(({ destination }) => destination)).toEqual(['pedidos_ayuda']);
  });
});
