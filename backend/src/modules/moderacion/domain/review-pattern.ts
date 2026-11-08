const DEVICE_REVIEW_THRESHOLD = 5;

export function isSuspiciousReviewBurst(reviewCount: number): boolean {
  return reviewCount >= DEVICE_REVIEW_THRESHOLD;
}
