import { newId } from '../../../shared/domain/ids.js';
import { decodeServiceCursor, encodeServiceCursor } from './service-cursor.js';

it('el cursor conserva solo vistos buenos, puntaje e id, sin coordenadas', () => {
  const cursor = { v: 3, p: 4.875, id: newId() };
  const encoded = encodeServiceCursor(cursor);
  expect(decodeServiceCursor(encoded)).toEqual(cursor);
  expect(JSON.parse(Buffer.from(encoded, 'base64url').toString('utf8'))).toEqual(cursor);
});

it('rechaza formato, tamaño y base64 no canónico', () => {
  for (const value of ['!', 'a'.repeat(513), 'e30=', 'a', '']) {
    expect(() => decodeServiceCursor(value)).toThrow(
      expect.objectContaining({ code: 'validacion' }),
    );
  }
});

it('rechaza cursores que no contienen exactamente las tres claves válidas', () => {
  const valid = { v: 1, p: 4.5, id: newId() };
  for (const data of [
    null,
    [],
    {},
    { ...valid, lat: -12 },
    { v: 1, id: valid.id },
    { ...valid, v: -1 },
    { ...valid, v: 1.5 },
    { ...valid, v: 2147483648 },
    { ...valid, p: 5.1 },
    { ...valid, p: -0.1 },
    { ...valid, p: 4.12345 },
    { ...valid, p: null },
    { ...valid, id: 'inexistente' },
  ]) {
    const encoded = Buffer.from(JSON.stringify(data)).toString('base64url');
    expect(() => decodeServiceCursor(encoded)).toThrow(
      expect.objectContaining({ code: 'validacion' }),
    );
  }
});
