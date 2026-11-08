import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import type { ContentForModeration } from '../../../shared/moderation/content-moderation.js';
import { PublicationPolicy } from '../../../shared/moderation/publication-policy.js';
import type { ImageScreening } from '../domain/screening.js';
import { ScreenContent } from './screen-content.js';

const tx = {} as TransactionContext;
const now = new Date('2026-11-09T15:00:00Z');
const content: ContentForModeration = {
  ownerId: '01970000-0000-7000-8000-000000000001',
  text: ['Reparó la ducha el mismo día.'],
  imageIds: [],
};

function setup({
  trust = 2,
  suspended = false,
  image = 'limpia',
}: {
  trust?: number;
  suspended?: boolean;
  image?: ImageScreening;
} = {}) {
  const stages: string[] = [];
  const publication = new PublicationPolicy();
  publication.register(async () => {
    stages.push('sancion');
    return suspended;
  });
  const filter = new ScreenContent(
    {
      inspect: async (id) => {
        stages.push(id);
        return image;
      },
    },
    {
      trustLevel: async () => {
        stages.push('reputacion');
        return trust;
      },
    },
    publication,
  );
  return { filter, stages };
}

describe('Cadena de moderación', () => {
  it('detecta insultos con tilde y puntuación sin marcar palabras por coincidencia parcial', async () => {
    const { filter } = setup();
    await expect(filter.evaluate(tx, { ...content, text: ['¡ImBÉCiL!'] }, now)).resolves.toBe(
      'texto_bloqueado',
    );
    await expect(
      filter.evaluate(tx, { ...content, text: ['El idioma de este texto es español'] }, now),
    ).resolves.toBeNull();
    await expect(filter.evaluate(tx, content, now, 'El detalle dice IDIOTA.')).resolves.toBe(
      'texto_bloqueado',
    );
  });

  it('consulta cada imagen una vez antes de la reputación y deriva imágenes dudosas o sin verificar', async () => {
    for (const [image, expected] of [
      ['dudosa', 'imagen_dudosa'],
      ['sin_verificar', 'imagen_sin_verificar'],
    ] as const) {
      const { filter, stages } = setup({ image });
      await expect(
        filter.evaluate(tx, { ...content, imageIds: ['foto-a', 'foto-a'] }, now),
      ).resolves.toBe(expected);
      expect(stages).toEqual(['foto-a', 'reputacion', 'sancion']);
    }
  });

  it('permite la reseña limpia del vecino de nivel 2 y deriva cuentas sin confianza o sancionadas', async () => {
    await expect(setup().filter.evaluate(tx, content, now)).resolves.toBeNull();
    await expect(setup({ trust: 1 }).filter.evaluate(tx, content, now)).resolves.toBe(
      'autor_no_verificado',
    );
    await expect(setup({ suspended: true }).filter.evaluate(tx, content, now)).resolves.toBe(
      'autor_suspendido',
    );
  });

  it('abre revisión por patrón desde la quinta reseña del mismo dispositivo', async () => {
    const { filter } = setup();
    await expect(
      filter.evaluate(tx, { ...content, deviceReviewCount: 4 }, now),
    ).resolves.toBeNull();
    await expect(filter.evaluate(tx, { ...content, deviceReviewCount: 5 }, now)).resolves.toBe(
      'patron_de_resenas',
    );
  });
});
