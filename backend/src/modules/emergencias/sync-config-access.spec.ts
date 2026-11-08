import { readFileSync } from 'node:fs';
import {
  DEFAULT_HYDRATION_STATE,
  parseSyncConfig,
  RequestJwtPayload,
  RequestParameters,
} from '@powersync/service-sync-rules';
import { describe, expect, it } from 'vitest';

const yaml = readFileSync(
  new URL('../../../../infra/powersync/sync-config.yaml', import.meta.url),
  'utf8',
);
const { config } = parseSyncConfig(yaml, { defaultSchema: 'public' });
const cases = { connectionTag: 'default', schema: 'emergencias', name: 'pedidos_ayuda' };
const assignments = { ...cases, name: 'asignaciones' };
const history = { ...cases, name: 'historial_pedidos' };
const details = { ...cases, name: 'detalles_pedidos' };

describe('acceso a datos sensibles por Sync Streams', () => {
  it('los streams de pedidos exigen suscripción explícita y excluyen el detalle privado', () => {
    const emergencySources = config.bucketSources.filter((stream) =>
      stream.dataSources.some((source) =>
        [cases, assignments, history, details].some((table) => source.tableSyncsData(table)),
      ),
    );
    expect(emergencySources.map((stream) => stream.name)).toEqual(['caso_asignado', 'mi_pedido']);
    expect(emergencySources.every((stream) => !stream.subscribedToByDefault)).toBe(true);
    expect(
      emergencySources.some((stream) =>
        stream.dataSources.some((source) => source.tableSyncsData(details)),
      ),
    ).toBe(false);
  });

  it('solo entrega el caso solicitado al usuario asignado y lo revoca al finalizar', async () => {
    const rules = config.hydrate({ hydrationState: DEFAULT_HYDRATION_STATE, sqlite: null });
    const records = ['pedido-a', 'pedido-b'].flatMap((id) =>
      rules.evaluateRow({
        sourceTable: cases,
        record: {
          id,
          detalle: 'Datos de prueba',
          creado_en: '2026-11-07T00:00:00Z',
          vence_en: '2026-11-08T00:00:00Z',
          cerrado_en: null,
        },
      }),
    );

    async function delivered(
      user: string,
      pedido: string,
      roles = ['brigadista'],
      finalizadaEn: string | null = null,
    ) {
      const parameters = ['pedido-a', 'pedido-b'].flatMap((pedidoId) =>
        rules.evaluateParameterRow(assignments, {
          pedido_id: pedidoId,
          usuario_id: 'asignado',
          finalizada_en: finalizadaEn,
        }),
      );
      const { querier, errors } = rules.getBucketParameterQuerier({
        globalParameters: new RequestParameters(new RequestJwtPayload({ sub: user, roles }), {}),
        hasDefaultStreams: false,
        streams: {
          caso_asignado: [
            { opaque_id: 0, priorityOverride: null, parameters: { pedido_id: pedido } },
          ],
        },
      });
      expect(errors).toEqual([]);
      const dynamic = await querier.queryDynamicBucketDescriptions({
        async getParameterSets(lookups) {
          return lookups.map((lookup) => ({
            lookup,
            rows: parameters
              .filter(
                (entry) =>
                  entry.lookup.serializedRepresentation === lookup.serializedRepresentation,
              )
              .flatMap((entry) => entry.bucketParameters),
          }));
        },
      });
      const buckets = new Set(
        [...querier.staticBuckets, ...dynamic].map((bucket) => bucket.bucket),
      );
      return records.filter((row) => buckets.has(row.bucket)).map((row) => row.id);
    }

    expect(await delivered('vecino', 'pedido-a')).toEqual([]);
    expect(await delivered('asignado', 'pedido-a', [])).toEqual([]);
    expect(await delivered('asignado', 'pedido-a')).toEqual(['pedido-a']);
    expect(await delivered('asignado', 'pedido-a', ['coordinador'])).toEqual(['pedido-a']);
    expect(await delivered('asignado', 'pedido-a', ['brigadista'], '2026-11-07T01:00:00Z')).toEqual(
      [],
    );
  });
});
