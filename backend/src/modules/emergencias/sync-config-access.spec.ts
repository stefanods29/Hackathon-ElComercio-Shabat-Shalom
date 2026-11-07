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

describe('acceso a datos sensibles por Sync Streams', () => {
  it('solo caso_asignado puede emitir datos de emergencias y exige suscripción explícita', () => {
    const emergencySources = config.bucketSources.filter((stream) =>
      stream.dataSources.some(
        (source) => source.tableSyncsData(cases) || source.tableSyncsData(assignments),
      ),
    );
    expect(emergencySources.map((stream) => stream.name)).toEqual(['caso_asignado']);
    expect(emergencySources[0]?.subscribedToByDefault).toBe(false);
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
