import { newId } from '../../../shared/domain/ids.js';
import { ProviderProfile } from './provider-profile.js';

const NOW = new Date('2026-11-08T01:00:00Z');
const OWNER = newId();
const ZONE = newId();
const data = { publicName: '  Gasfitería Don Luis  ', description: '  Arreglos en casa  ' };

describe('ProviderProfile', () => {
  it('crea el perfil del vecino, normaliza textos y conserva su fecha al actualizar', () => {
    const profile = ProviderProfile.create(OWNER, ZONE, data, NOW);
    const later = new Date('2026-11-08T02:00:00Z');
    profile.update(OWNER, ZONE, { publicName: 'Gasfitería Luis', description: null }, later);
    expect(profile.snapshot()).toMatchObject({
      id: OWNER,
      zoneId: ZONE,
      publicName: 'Gasfitería Luis',
      description: null,
      createdAt: NOW,
      updatedAt: later,
      deletedAt: null,
      hiddenAt: null,
    });
  });

  it('solo el dueño cambia el perfil y su zona', () => {
    const profile = ProviderProfile.create(OWNER, ZONE, data, NOW);
    expect(() => profile.update(newId(), newId(), data, NOW)).toThrow(
      expect.objectContaining({ code: 'no_eres_el_dueno', kind: 'forbidden' }),
    );
    expect(profile.snapshot().zoneId).toBe(ZONE);
  });

  it('exige nombre público de 2 a 60 y descripción de hasta 500 caracteres', () => {
    for (const publicName of [' a ', 'a'.repeat(61)]) {
      expect(() => ProviderProfile.create(OWNER, ZONE, { ...data, publicName }, NOW)).toThrow();
    }
    expect(() =>
      ProviderProfile.create(OWNER, ZONE, { ...data, description: 'a'.repeat(501) }, NOW),
    ).toThrow(expect.objectContaining({ code: 'descripcion_invalida' }));
  });
});
