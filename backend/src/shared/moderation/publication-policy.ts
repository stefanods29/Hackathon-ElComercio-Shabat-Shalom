import { Injectable } from '@nestjs/common';
import type { TransactionContext } from '../db/unit-of-work.js';
import { BusinessRuleViolation } from '../domain/errors.js';

export type IsSuspended = (userId: string, now: Date, tx?: TransactionContext) => Promise<boolean>;

@Injectable()
export class PublicationPolicy {
  private read?: IsSuspended;

  register(reader: IsSuspended): void {
    if (this.read) throw new Error('Ya está registrado el lector de sanciones.');
    this.read = reader;
  }

  isSuspended(userId: string, now: Date, tx?: TransactionContext): Promise<boolean> {
    if (!this.read) throw new Error('Falta el lector de sanciones.');
    return this.read(userId, now, tx);
  }

  async requirePublication(tx: TransactionContext, userId: string, now: Date): Promise<void> {
    if (await this.isSuspended(userId, now, tx)) {
      throw new BusinessRuleViolation(
        'cuenta_suspendida',
        'Tu cuenta tiene una suspensión de publicación vigente.',
        'forbidden',
      );
    }
  }
}
