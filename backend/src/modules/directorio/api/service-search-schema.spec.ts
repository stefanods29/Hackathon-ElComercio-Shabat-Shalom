import { serviceSearchSchema } from './schemas.js';

it('aplica radio, límite y emergencia por defecto sin confundir false con true', () => {
  expect(serviceSearchSchema.parse({ lat: '-12', lng: '-77' })).toEqual({
    lat: -12,
    lng: -77,
    radioM: 2000,
    limite: 20,
    soloEmergencia: false,
  });
  expect(
    serviceSearchSchema.parse({ lat: '-12', lng: '-77', soloEmergencia: 'false' }).soloEmergencia,
  ).toBe(false);
  expect(
    serviceSearchSchema.parse({ lat: '-12', lng: '-77', soloEmergencia: 'true' }).soloEmergencia,
  ).toBe(true);
});

it('valida rangos, tipos, límites, texto, categoría y campos desconocidos', () => {
  const valid = { lat: '-12', lng: '-77' };
  for (const changes of [
    { lat: '91' },
    { lng: '-181' },
    { lat: '' },
    { lat: '0x10' },
    { lng: 'Infinity' },
    { radioM: '99' },
    { radioM: '20001' },
    { radioM: '100.5' },
    { limite: '0' },
    { limite: '51' },
    { soloEmergencia: '1' },
    { q: '  ' },
    { q: 'a'.repeat(121) },
    { categoriaId: 'gasfitería' },
    { lat: ['-12', '-13'] },
    { cursor: '' },
    { zonaId: 'arbitraria' },
  ])
    expect(serviceSearchSchema.safeParse({ ...valid, ...changes }).success).toBe(false);
});
