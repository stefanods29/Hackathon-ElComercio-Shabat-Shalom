import { averageRating, bayesianScore } from './reputation-ranking.js';

it('calcula a mano el puntaje con peso 7 y media 4: (28 + 9) / 9', () => {
  expect(averageRating(9, 2)).toBe(4.5);
  expect(bayesianScore(9, 2, 4)).toBeCloseTo(37 / 9, 12);
});

it('con media 4 prioriza 80 reseñas de 4,8 frente a una sola de 5', () => {
  expect(bayesianScore(5, 1, 4)).toBe(33 / 8);
  expect(bayesianScore(384, 80, 4)).toBe(412 / 87);
  expect(bayesianScore(384, 80, 4)).toBeGreaterThan(bayesianScore(5, 1, 4));
});

it('el promedio sin reseñas es cero y el puntaje usa la media de la categoría', () => {
  expect(averageRating(0, 0)).toBe(0);
  expect(bayesianScore(0, 0, 4)).toBe(4);
  expect(bayesianScore(0, 0, 0)).toBe(0);
});
