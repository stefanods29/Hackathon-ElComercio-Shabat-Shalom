import { newId } from '../../../shared/domain/ids.js';
import { Service, SERVICE_PUBLISHED_EVENT, type ServiceData, attributesFit } from './service.js';

const NOW = new Date('2026-11-08T01:00:00Z');
const LATER = new Date('2026-11-08T02:00:00Z');
const OWNER = newId();
const ZONE = newId();
const data: ServiceData = {
  categoryId: 'gasfiteria',
  title: 'Gasfitero a domicilio',
  description: null,
  location: { lat: -12.085678, lng: -77.034567 },
  showExactLocation: false,
  coverageRadiusMeters: 2000,
  availableInEmergency: true,
  attributes: {},
};
const create = (changes: Partial<ServiceData> = {}) =>
  Service.create({ ...data, ...changes, id: newId(), providerId: OWNER, zoneId: ZONE }, NOW);

describe('Service', () => {
  it('nace en versión 1, con agregados en cero y un único evento público sin ubicación', () => {
    const service = create();
    expect(service.snapshot()).toMatchObject({
      version: 1,
      reviewCount: 0,
      rankingScore: 0,
      zoneEndorsementCount: 0,
      createdAt: NOW,
      deletedAt: null,
    });
    expect(service.pullEvents()).toEqual([
      {
        type: SERVICE_PUBLISHED_EVENT,
        aggregateId: service.id,
        occurredAt: NOW,
        payload: { proveedorId: OWNER, zonaId: ZONE, categoriaId: 'gasfiteria' },
      },
    ]);
    expect(service.pullEvents()).toEqual([]);
  });

  it('conserva la ubicación privada y redondea únicamente la copia pública', () => {
    expect(create().snapshot()).toMatchObject({
      location: data.location,
      publicLocation: { lat: -12.086, lng: -77.035 },
    });
  });

  it('muestra el local solo con aceptación explícita y vuelve a redondear al retirarla', () => {
    const service = create({ showExactLocation: true });
    expect(service.snapshot().publicLocation).toEqual(data.location);
    service.edit(OWNER, 1, data, LATER);
    expect(service.snapshot()).toMatchObject({
      showExactLocation: false,
      publicLocation: { lat: -12.086, lng: -77.035 },
      version: 2,
      updatedAt: LATER,
    });
  });

  it('solo el dueño edita o retira, incluso después del retiro', () => {
    const service = create();
    expect(() => service.edit(newId(), 1, data, LATER)).toThrow(
      expect.objectContaining({ code: 'no_eres_el_dueno', kind: 'forbidden' }),
    );
    service.withdraw(OWNER, LATER);
    expect(() => service.withdraw(newId(), LATER)).toThrow(
      expect.objectContaining({ code: 'no_eres_el_dueno' }),
    );
  });

  it('una versión vieja no cambia el servicio y explica ambas versiones', () => {
    const service = create();
    service.edit(OWNER, 1, { ...data, title: 'Servicio editado' }, LATER);
    const before = service.snapshot();
    expect(() => service.edit(OWNER, 1, data, LATER)).toThrow(
      expect.objectContaining({
        code: 'conflicto_de_version',
        expectedVersion: 1,
        currentVersion: 2,
      }),
    );
    expect(service.snapshot()).toEqual(before);
  });

  it('editar conserva los agregados de reputación y las marcas de moderación', () => {
    const service = Service.restore({
      ...create().snapshot(),
      reviewCount: 8,
      ratingSum: 37,
      average: 4.63,
      rankingScore: 4.4,
      endorsementCount: 5,
      zoneEndorsementCount: 3,
      hiddenAt: NOW,
    });
    service.edit(OWNER, 1, { ...data, title: 'Servicio actualizado' }, LATER);
    expect(service.snapshot()).toMatchObject({
      reviewCount: 8,
      ratingSum: 37,
      rankingScore: 4.4,
      endorsementCount: 5,
      zoneEndorsementCount: 3,
      hiddenAt: NOW,
    });
  });

  it('el retiro es idempotente, no cambia la fecha ni la versión al repetir y no resucita', () => {
    const service = create();
    expect(service.withdraw(OWNER, NOW)).toBe(true);
    expect(service.withdraw(OWNER, LATER)).toBe(false);
    expect(service.snapshot()).toMatchObject({ deletedAt: NOW, updatedAt: NOW, version: 2 });
    expect(() => service.edit(OWNER, 2, data, LATER)).toThrow(
      expect.objectContaining({ code: 'servicio_retirado' }),
    );
  });

  it('exige UUIDv7 y valida título, ubicación, categoría, radio y descripción', () => {
    expect(() =>
      Service.create(
        { ...data, id: '01970000-0000-4000-8000-000000000111', providerId: OWNER, zoneId: ZONE },
        NOW,
      ),
    ).toThrow(expect.objectContaining({ code: 'id_invalido' }));
    for (const changes of [
      { title: 'a' },
      { location: { lat: NaN, lng: -77 } },
      { location: { lat: -12, lng: 181 } },
      { categoryId: 'categoría inválida' },
      { coverageRadiusMeters: 99 },
      { coverageRadiusMeters: 20001 },
      { description: 'a'.repeat(2001) },
    ]) {
      expect(() => create(changes)).toThrow();
    }
  });

  it('limita los atributos a 4 KB en UTF-8, contando los bytes de las tildes', () => {
    expect(attributesFit({ texto: 'á'.repeat(2042) })).toBe(true);
    expect(attributesFit({ texto: 'á'.repeat(2043) })).toBe(false);
    expect(() => create({ attributes: { texto: 'á'.repeat(2043) } })).toThrow(
      expect.objectContaining({ code: 'atributos_invalidos' }),
    );
  });

  it('no permite que una referencia externa cambie la ubicación o los atributos', () => {
    const attributes = { horario: { dias: ['lunes'] } };
    const service = create({ attributes });
    attributes.horario.dias.push('martes');
    const snapshot = service.snapshot();
    (snapshot.attributes.horario as { dias: string[] }).dias.push('miércoles');
    expect(service.snapshot().attributes).toEqual({ horario: { dias: ['lunes'] } });
  });
});
