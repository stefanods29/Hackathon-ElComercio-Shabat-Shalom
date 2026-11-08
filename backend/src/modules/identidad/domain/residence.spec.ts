import { ensurePresenceDateAllowed, ensureZoneChangeAllowed, residenceDay } from './residence.js';

describe('Ventanas de residencia', () => {
  it('permite cambiar de zona en el instante exacto en que se cumplen 30 días', () => {
    const chosen = new Date('2026-10-08T17:00:00Z');
    const available = new Date('2026-11-07T17:00:00Z');
    expect(() => ensureZoneChangeAllowed(chosen, new Date(available.getTime() - 1))).toThrow(
      expect.objectContaining({
        code: 'cambio_de_zona_muy_pronto',
        extensions: { disponibleDesde: available.toISOString() },
      }),
    );
    expect(() => ensureZoneChangeAllowed(chosen, available)).not.toThrow();
  });

  it('cuenta 14 fechas locales en Lima y descarta las de la zona anterior', () => {
    const now = new Date('2026-11-08T02:00:00Z');
    expect(residenceDay(now)).toBe('2026-11-07');
    expect(() => ensurePresenceDateAllowed('2026-10-25', null, now)).not.toThrow();
    for (const date of ['2026-10-24', '2026-11-08']) {
      expect(() => ensurePresenceDateAllowed(date, null, now)).toThrow(
        expect.objectContaining({ code: 'fecha_de_presencia_invalida' }),
      );
    }
    const chosen = new Date('2026-11-06T16:00:00Z');
    expect(() => ensurePresenceDateAllowed('2026-11-05', chosen, now)).toThrow(
      expect.objectContaining({ code: 'fecha_de_presencia_invalida' }),
    );
    expect(() => ensurePresenceDateAllowed('2026-11-06', chosen, now)).not.toThrow();
  });
});
