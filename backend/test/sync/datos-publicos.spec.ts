import { readFileSync } from 'node:fs';
import {
  DEFAULT_HYDRATION_STATE,
  parseSyncConfig,
  RequestJwtPayload,
  RequestParameters,
} from '@powersync/service-sync-rules';
import { describe, expect, it } from 'vitest';

/**
 * Access tests of the public Sync Streams (ADR 0010, `sincronizacion/datos-publicos`): what each
 * phone receives from the directory, the reputation and the wall, evaluated with the same parser
 * the PowerSync service uses.
 */
const yaml = readFileSync(
  new URL('../../../infra/powersync/sync-config.yaml', import.meta.url),
  'utf8',
);
const { config } = parseSyncConfig(yaml, { defaultSchema: 'public' });
const rules = config.hydrate({ hydrationState: DEFAULT_HYDRATION_STATE, sqlite: null });

const PILOT = 'zona-piloto';
const NEIGHBOR = 'zona-vecina';
const HIDDEN_AT = '2026-11-07T12:00:00Z';

// PostgreSQL booleans reach PowerSync as integers (1 or 0).
type SourceRecord = Record<string, string | number | null>;
const table = (schema: string, name: string) => ({ connectionTag: 'default', schema, name });

/** Rows as they live in PostgreSQL, private columns included, to prove they never travel. */
const sourceRows: Array<[ReturnType<typeof table>, SourceRecord]> = [
  [
    table('directorio', 'categorias'),
    {
      id: 'gasfiteria',
      nombre: 'Gasfitería',
      icono: 'plumbing',
      util_en_emergencia: 1,
      orden: 1,
    },
  ],
  [
    table('directorio', 'proveedores'),
    {
      id: 'p-piloto',
      zona_id: PILOT,
      nombre_publico: 'Don Luis',
      descripcion: null,
      telefono: '+51900000009',
      eliminado_en: null,
      oculto_en: null,
    },
  ],
  [
    table('directorio', 'proveedores'),
    {
      id: 'p-oculto',
      zona_id: PILOT,
      nombre_publico: 'Oculto',
      eliminado_en: null,
      oculto_en: HIDDEN_AT,
    },
  ],
  [
    table('directorio', 'proveedores'),
    {
      id: 'p-vecina',
      zona_id: NEIGHBOR,
      nombre_publico: 'Otra zona',
      eliminado_en: null,
      oculto_en: null,
    },
  ],
  [
    table('directorio', 'servicios'),
    {
      id: 's-piloto',
      proveedor_id: 'p-piloto',
      zona_id: PILOT,
      categoria_id: 'gasfiteria',
      titulo: 'Arreglo fugas',
      lat_publica: -12.086,
      lng_publica: -77.035,
      ubicacion: 'POINT(-77.034567 -12.085678)',
      muestra_ubicacion_exacta: 0,
      suma_calificaciones: 9,
      eliminado_en: null,
      oculto_en: null,
    },
  ],
  [
    table('directorio', 'servicios'),
    {
      id: 's-oculto',
      proveedor_id: 'p-piloto',
      zona_id: PILOT,
      titulo: 'Oculto',
      eliminado_en: null,
      oculto_en: HIDDEN_AT,
    },
  ],
  [
    table('directorio', 'servicios'),
    {
      id: 's-retirado',
      proveedor_id: 'p-piloto',
      zona_id: PILOT,
      titulo: 'Retirado',
      eliminado_en: HIDDEN_AT,
      oculto_en: null,
    },
  ],
  [
    table('directorio', 'servicios'),
    {
      id: 's-vecina',
      proveedor_id: 'p-vecina',
      zona_id: NEIGHBOR,
      titulo: 'Otra zona',
      eliminado_en: null,
      oculto_en: null,
    },
  ],
  [
    table('reputacion', 'resenas'),
    {
      id: 'r-publicada',
      servicio_id: 's-piloto',
      autor_id: 'ana',
      zona_autor_id: PILOT,
      calificacion: 5,
      comentario: 'Muy bien',
      estado: 'publicada',
    },
  ],
  [
    table('reputacion', 'resenas'),
    {
      id: 'r-revision',
      servicio_id: 's-piloto',
      autor_id: 'beto',
      zona_autor_id: PILOT,
      calificacion: 4,
      estado: 'en_revision',
    },
  ],
  [
    table('reputacion', 'resenas'),
    {
      id: 'r-oculta',
      servicio_id: 's-piloto',
      autor_id: 'ana',
      zona_autor_id: PILOT,
      calificacion: 1,
      estado: 'oculta',
    },
  ],
  [
    table('reputacion', 'resenas'),
    {
      id: 'r-de-oculto',
      servicio_id: 's-oculto',
      autor_id: 'ana',
      calificacion: 5,
      estado: 'publicada',
    },
  ],
  [
    table('reputacion', 'resenas'),
    {
      id: 'r-vecina',
      servicio_id: 's-vecina',
      autor_id: 'elena',
      calificacion: 3,
      estado: 'publicada',
    },
  ],
  [
    table('reputacion', 'resena_fotos'),
    { id: 'f-publicada', resena_id: 'r-publicada', archivo_id: 'a1', orden: 0, oculta_en: null },
  ],
  [
    table('reputacion', 'resena_fotos'),
    { id: 'f-oculta', resena_id: 'r-publicada', archivo_id: 'a2', orden: 1, oculta_en: HIDDEN_AT },
  ],
  [
    table('reputacion', 'resena_fotos'),
    { id: 'f-revision', resena_id: 'r-revision', archivo_id: 'a3', orden: 0, oculta_en: null },
  ],
  [
    table('reputacion', 'resena_fotos'),
    { id: 'f-de-oculto', resena_id: 'r-de-oculto', archivo_id: 'a4', orden: 0, oculta_en: null },
  ],
  [
    table('reputacion', 'vistos_buenos'),
    { id: 'v-beto', servicio_id: 's-piloto', vecino_id: 'beto', nivel_al_dar: 1 },
  ],
  [
    table('reputacion', 'vistos_buenos'),
    { id: 'v-ana', servicio_id: 's-piloto', vecino_id: 'ana', nivel_al_dar: 2 },
  ],
  [
    table('solidaridad', 'publicaciones'),
    {
      id: 'pub-visible',
      autor_id: 'ana',
      zona_id: PILOT,
      titulo: 'Presto taladro',
      eliminado_en: null,
      oculta_en: null,
    },
  ],
  [
    table('solidaridad', 'publicaciones'),
    {
      id: 'pub-oculta',
      autor_id: 'beto',
      zona_id: PILOT,
      titulo: 'Oculta',
      eliminado_en: null,
      oculta_en: HIDDEN_AT,
    },
  ],
  [
    table('solidaridad', 'publicaciones'),
    {
      id: 'pub-borrada',
      autor_id: 'ana',
      zona_id: PILOT,
      titulo: 'Borrada',
      eliminado_en: HIDDEN_AT,
      oculta_en: null,
    },
  ],
];

const dataRows = sourceRows.flatMap(([sourceTable, record]) =>
  rules.evaluateRow({ sourceTable, record }),
);
const parameterRows = sourceRows.flatMap(([sourceTable, record]) =>
  rules.evaluateParameterRow(sourceTable, record),
);

/** `<tabla local>:<id>` of every row the phone of `sub` in `zona` receives. */
async function delivered(sub: string, zona: string): Promise<string[]> {
  const { querier, errors } = rules.getBucketParameterQuerier({
    globalParameters: new RequestParameters(new RequestJwtPayload({ sub, zona, roles: [] }), {}),
    hasDefaultStreams: true,
    streams: {},
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
  return dataRows
    .filter((row) => buckets.has(row.bucket))
    .map((row) => `${row.table}:${row.id}`)
    .sort();
}

describe('Sync Streams de datos públicos', () => {
  it('un vecino de la zona piloto recibe solo lo vigente y público de su zona', async () => {
    expect(await delivered('beto', PILOT)).toEqual(
      [
        'categorias:gasfiteria',
        'fotos_resena:f-publicada',
        'mis_resenas:r-revision',
        'mis_vistos_buenos:v-beto',
        'proveedores:p-piloto',
        'publicaciones:pub-visible',
        'resenas:r-publicada',
        'servicios:s-piloto',
      ].sort(),
    );
  });

  it('un vecino de otra zona no recibe filas de la zona piloto', async () => {
    const rows = await delivered('elena', NEIGHBOR);
    expect(rows).toEqual(
      [
        'categorias:gasfiteria',
        'mis_resenas:r-vecina',
        'proveedores:p-vecina',
        'resenas:r-vecina',
        'servicios:s-vecina',
      ].sort(),
    );
  });

  it('una reseña en revisión solo llega a su autor y sus fotos a nadie', async () => {
    const author = await delivered('beto', PILOT);
    const other = await delivered('ana', PILOT);
    expect(author).toContain('mis_resenas:r-revision');
    expect(author).not.toContain('resenas:r-revision');
    expect(other.filter((row) => row.endsWith(':r-revision'))).toEqual([]);
    expect([...author, ...other]).not.toContain('fotos_resena:f-revision');
  });

  it('lo oculto o borrado no llega a ningún vecino de la zona', async () => {
    const rows = await delivered('carla', PILOT);
    for (const id of [
      'p-oculto',
      's-oculto',
      's-retirado',
      'r-oculta',
      'r-de-oculto',
      'f-oculta',
      'f-de-oculto',
      'pub-oculta',
      'pub-borrada',
    ]) {
      expect(rows.filter((row) => row.endsWith(`:${id}`))).toEqual([]);
    }
  });

  it('el autor ve su reseña oculta con su estado, pero nadie más la recibe', async () => {
    expect(await delivered('ana', PILOT)).toContain('mis_resenas:r-oculta');
    expect(await delivered('beto', PILOT)).not.toContain('mis_resenas:r-oculta');
  });

  it('los Visto Bueno de otros vecinos solo viajan como contador del servicio', async () => {
    expect(await delivered('beto', PILOT)).not.toContain('mis_vistos_buenos:v-ana');
  });

  it('ningún stream automático lleva columnas privadas', () => {
    const forbidden = ['ubicacion', 'telefono', 'direccion', 'muestra_ubicacion_exacta'];
    const forbiddenInReputation = ['autor_id', 'vecino_id', 'zona_autor_id', 'nivel_al_dar'];
    for (const row of dataRows) {
      const columns = Object.keys(row.data);
      expect(columns.filter((column) => forbidden.includes(column))).toEqual([]);
      if (['resenas', 'mis_resenas', 'fotos_resena', 'mis_vistos_buenos'].includes(row.table)) {
        expect(columns.filter((column) => forbiddenInReputation.includes(column))).toEqual([]);
      }
    }
  });

  it('la ubicación de un servicio es la copia pública y no la exacta', () => {
    const service = dataRows.find((row) => row.table === 'servicios' && row.id === 's-piloto');
    expect(service?.data).toMatchObject({ lat: -12.086, lng: -77.035 });
    expect(JSON.stringify(service?.data)).not.toContain('034567');
  });

  it('todos los streams de datos públicos se suscriben solos', () => {
    const publicStreams = config.bucketSources.filter((stream) => stream.name !== 'caso_asignado');
    expect(publicStreams.every((stream) => stream.subscribedToByDefault)).toBe(true);
  });
});
