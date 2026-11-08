const PRIOR_WEIGHT = 7;

export function averageRating(ratingSum: number, reviewCount: number): number {
  return reviewCount === 0 ? 0 : ratingSum / reviewCount;
}

export function bayesianScore(
  ratingSum: number,
  reviewCount: number,
  categoryMean: number,
): number {
  return (PRIOR_WEIGHT * categoryMean + ratingSum) / (PRIOR_WEIGHT + reviewCount);
}
