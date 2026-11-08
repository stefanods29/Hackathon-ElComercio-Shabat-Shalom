export interface EndorsementData {
  readonly serviceId: string;
  readonly neighborId: string;
  readonly neighborZoneId: string;
  readonly trustLevelAtGiving: number;
  readonly createdAt: Date;
}

export interface Endorsement extends EndorsementData {
  readonly id: string;
}

export const MIN_RANKING_TRUST_LEVEL = 2;

export function countsForRanking(endorsement: Endorsement): boolean {
  return endorsement.trustLevelAtGiving >= MIN_RANKING_TRUST_LEVEL;
}
