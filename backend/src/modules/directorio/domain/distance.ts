/** Distance is public only in 50 m buckets; the exact search point is not persisted. */
export function publicDistanceMeters(distanceMeters: number): number {
  return Math.round(distanceMeters / 50) * 50;
}
