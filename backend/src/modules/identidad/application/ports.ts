import type { Actor } from '../../../shared/auth/actor.js';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';

export interface RegisteredUser extends Actor {
  readonly phone: string;
  readonly displayName: string;
}

export interface UserRepository {
  findByPhone(phone: string): Promise<RegisteredUser | null>;
  findById(id: string): Promise<RegisteredUser | null>;
  findOrCreateByPhone(transaction: TransactionContext, phone: string): Promise<RegisteredUser>;
  assignZone(
    transaction: TransactionContext,
    userId: string,
    zoneId: string,
  ): Promise<RegisteredUser | null>;
}

export const USER_REPOSITORY = Symbol('USER_REPOSITORY');

export interface ZoneSummary {
  readonly id: string;
  readonly name: string;
  readonly district: string;
}

export interface ZoneRepository {
  list(): Promise<ZoneSummary[]>;
  exists(transaction: TransactionContext, id: string): Promise<boolean>;
}

export const ZONE_REPOSITORY = Symbol('ZONE_REPOSITORY');

export type OtpChannel = 'sms' | 'whatsapp';

export interface OtpProvider {
  send(phone: string, code: string, channel: OtpChannel): Promise<void>;
}

export const OTP_PROVIDER = Symbol('OTP_PROVIDER');

export interface OtpCodeRecord {
  readonly id: string;
  readonly phone: string;
  readonly codeHash: string;
  readonly channel: OtpChannel;
  readonly ip: string | null;
  readonly attempts: number;
  readonly expiresAt: Date;
  readonly usedAt: Date | null;
  readonly createdAt: Date;
}

export interface OtpCodeRepository {
  lockRequestWindow(
    transaction: TransactionContext,
    phone: string,
    ip: string | null,
  ): Promise<void>;
  create(transaction: TransactionContext, record: OtpCodeRecord): Promise<void>;
  findLatestActiveForUpdate(
    transaction: TransactionContext,
    phone: string,
    now: Date,
  ): Promise<OtpCodeRecord | null>;
  countByPhoneSince(
    phone: string,
    since: Date,
    transaction?: TransactionContext,
  ): Promise<{ count: number; oldest: Date | null }>;
  countByIpSince(
    ip: string,
    since: Date,
    transaction?: TransactionContext,
  ): Promise<{ count: number; oldest: Date | null }>;
  incrementAttempts(transaction: TransactionContext, id: string): Promise<number>;
  markUsed(transaction: TransactionContext, id: string, now: Date): Promise<boolean>;
}

export const OTP_CODE_REPOSITORY = Symbol('OTP_CODE_REPOSITORY');
