import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import type { OtpCodeRecord, OtpCodeRepository } from '../application/ports.js';

export class InMemoryOtpCodeRepository implements OtpCodeRepository {
  private readonly rows = new Map<string, OtpCodeRecord>();

  async lockRequestWindow(): Promise<void> {}

  async create(_transaction: TransactionContext, record: OtpCodeRecord): Promise<void> {
    this.rows.set(record.id, structuredClone(record));
  }

  async findLatestActiveForUpdate(
    _transaction: TransactionContext,
    phone: string,
    now: Date,
  ): Promise<OtpCodeRecord | null> {
    const row = [...this.rows.values()]
      .filter(
        (candidate) =>
          candidate.phone === phone &&
          candidate.usedAt === null &&
          candidate.expiresAt.getTime() > now.getTime(),
      )
      .sort(
        (left, right) =>
          right.createdAt.getTime() - left.createdAt.getTime() || right.id.localeCompare(left.id),
      )[0];
    return row ? structuredClone(row) : null;
  }

  async countByPhoneSince(
    phone: string,
    since: Date,
  ): Promise<{ count: number; oldest: Date | null }> {
    return this.count((row) => row.phone === phone, since);
  }

  async countByIpSince(ip: string, since: Date): Promise<{ count: number; oldest: Date | null }> {
    return this.count((row) => row.ip === ip, since);
  }

  async incrementAttempts(_transaction: TransactionContext, id: string): Promise<number> {
    const row = this.rows.get(id);
    if (!row) throw new Error('Código OTP inexistente');
    const attempts = row.attempts + 1;
    this.rows.set(id, { ...row, attempts });
    return attempts;
  }

  async markUsed(_transaction: TransactionContext, id: string, now: Date): Promise<boolean> {
    const row = this.rows.get(id);
    if (!row || row.usedAt !== null) return false;
    this.rows.set(id, { ...row, usedAt: now });
    return true;
  }

  private count(
    predicate: (row: OtpCodeRecord) => boolean,
    since: Date,
  ): { count: number; oldest: Date | null } {
    const matches = [...this.rows.values()].filter(
      (row) => predicate(row) && row.createdAt.getTime() >= since.getTime(),
    );
    const oldest = matches.length
      ? new Date(Math.min(...matches.map((row) => row.createdAt.getTime())))
      : null;
    return { count: matches.length, oldest };
  }
}
