import { errorCategory, privateEvent, safeRoute } from './privacy.js';
describe('privacidad del monitoreo', () => {
  it('excluye valores, usuarios, solicitudes, contexto y breadcrumbs', () => {
    const input = {
      message: 'token secreto',
      user: { id: 'vecino' },
      request: { headers: { authorization: 'Bearer privado' }, data: { ubicacion: '-12,-77' } },
      breadcrumbs: [{ message: 'foto privada' }],
      contexts: { vecino: 'Ana' },
      exception: { values: [{ type: 'Error', value: 'teléfono +51999999999' }] },
    };
    const serialized = JSON.stringify(privateEvent(input));
    for (const secret of [
      'secreto',
      'vecino',
      'Bearer',
      'ubicacion',
      '+51999999999',
      'privada',
      'Ana',
    ])
      expect(serialized).not.toContain(secret);
  });
  it('solo usa plantillas de ruta y categorías conocidas', () => {
    expect(safeRoute('/v1/archivos/:id')).toBe('/v1/archivos/:id');
    expect(safeRoute('/v1/archivos?token=privado')).toBe('unmatched');
    expect(safeRoute('/v1/archivos/01970000-0000-7000-8000-00000000f001')).toBe('unmatched');
    expect(errorCategory(new Error('dato privado'))).toBe('Error');
    expect(
      privateEvent({ exception: { values: [{ type: 'NombrePrivado' }] } }).exception.values[0]
        ?.type,
    ).toBe('Error');
  });
});
