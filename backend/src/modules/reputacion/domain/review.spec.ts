import { newId } from '../../../shared/domain/ids.js';
import { Review, type NewReview, type ReviewPhoto } from './review.js';

const now = new Date('2026-11-08T03:00:00Z');
const base: NewReview = {
  id: newId(),
  serviceId: newId(),
  authorId: newId(),
  authorZoneId: newId(),
  rating: 5,
  comment: '  Buen servicio  ',
  photos: [],
};

describe('Review', () => {
  it('nace en revisión, normaliza el comentario y registra una vez su evento sin contenido ni fotos', () => {
    const review = Review.create(base, now);
    expect(review.snapshot()).toMatchObject({
      state: 'en_revision',
      comment: 'Buen servicio',
      createdAt: now,
      publishedAt: null,
      stateReason: null,
    });
    expect(review.pullEvents()).toEqual([
      {
        type: 'reputacion.resena_creada',
        aggregateId: base.id,
        occurredAt: now,
        payload: { servicioId: base.serviceId, autorId: base.authorId },
      },
    ]);
    expect(review.pullEvents()).toEqual([]);
    expect(Review.restore(review.snapshot()).pullEvents()).toEqual([]);
  });

  it('valida id del celular, estrellas enteras, comentario y máximo de tres fotos distintas', () => {
    const photo = (): ReviewPhoto => ({
      id: newId(),
      fileId: newId(),
      order: 0,
      width: 320,
      height: 200,
      blurhash: null,
      hiddenAt: null,
    });
    const repeated = photo();
    for (const invalid of [
      { id: '01970000-0000-4000-8000-000000000111' },
      { rating: 0 },
      { rating: 6 },
      { rating: 3.5 },
      { comment: 'a'.repeat(2001) },
      { photos: [photo(), photo(), photo(), photo()] },
      { photos: [repeated, repeated] },
    ]) {
      expect(() => Review.create({ ...base, ...invalid }, now)).toThrow(
        expect.objectContaining({ code: 'validacion' }),
      );
    }
  });
});
