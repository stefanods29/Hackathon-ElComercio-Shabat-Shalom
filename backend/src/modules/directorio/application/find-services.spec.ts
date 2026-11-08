import { newId } from '../../../shared/domain/ids.js';
import { FindServices } from './find-services.js';
import { encodeServiceCursor } from './service-cursor.js';
import type { ServiceSearchPage } from './search-ports.js';

const actor = { id: newId(), zoneId: newId(), trustLevel: 0 };
const query = {
  location: { lat: -12.085678, lng: -77.034567 },
  radiusMeters: 2000,
  emergencyOnly: false,
  limit: 20,
};

it('permite buscar desde nivel 0 y pasa los filtros y la zona certificada al puerto en memoria', async () => {
  const page: ServiceSearchPage = { data: [], nextCursor: null };
  const reader = { search: vi.fn(async () => page) };
  const find = new FindServices(reader);
  expect(
    await find.execute({ ...query, text: 'gásfiter', categoryId: 'gasfiteria' }, actor),
  ).toEqual(page);
  expect(reader.search).toHaveBeenCalledWith({
    ...query,
    text: 'gásfiter',
    categoryId: 'gasfiteria',
    zoneId: actor.zoneId,
    cursor: null,
  });
});

it('codifica el cursor de salida y decodifica el de entrada sin consultar el ancla', async () => {
  const cursor = { v: 3, p: 4.5, id: newId() };
  const reader = { search: vi.fn(async () => ({ data: [], nextCursor: cursor })) };
  const find = new FindServices(reader);
  const encoded = encodeServiceCursor(cursor);
  expect(await find.execute({ ...query, cursor: encoded }, actor)).toEqual({
    data: [],
    nextCursor: encoded,
  });
  expect(reader.search).toHaveBeenCalledWith(expect.objectContaining({ cursor }));
});

it('exige zona y rechaza el cursor inválido antes de invocar el puerto', async () => {
  const reader = { search: vi.fn(async () => ({ data: [], nextCursor: null })) };
  const find = new FindServices(reader);
  await expect(find.execute(query, { ...actor, zoneId: null })).rejects.toMatchObject({
    code: 'sin_zona',
  });
  for (const cursor of ['!', '']) {
    await expect(find.execute({ ...query, cursor }, actor)).rejects.toMatchObject({
      code: 'validacion',
    });
  }
  expect(reader.search).not.toHaveBeenCalled();
});
