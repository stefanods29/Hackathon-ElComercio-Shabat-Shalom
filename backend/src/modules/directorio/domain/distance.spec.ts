import { publicDistanceMeters } from './distance.js';

it('redondea 437 m a 450 m y nunca devuelve precisión menor a 50 m', () => {
  for (const [exact, expected] of [
    [0, 0],
    [24.9, 0],
    [25, 50],
    [437, 450],
    [474.9, 450],
    [475, 500],
    [19999.9, 20000],
  ]) {
    expect(publicDistanceMeters(exact!)).toBe(expected);
    expect(publicDistanceMeters(exact!) % 50).toBe(0);
  }
});
