import type { Actor } from '../../../shared/auth/actor.js';

export interface RegisteredUser extends Actor {
  readonly phone: string;
  readonly displayName: string;
}

/** Reads users to issue tokens. Sign-up with OTP is implemented by Lot B. */
export interface UserRepository {
  findByPhone(phone: string): Promise<RegisteredUser | null>;
  findById(id: string): Promise<RegisteredUser | null>;
}

export const USER_REPOSITORY = Symbol('USER_REPOSITORY');
