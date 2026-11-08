import { Injectable } from '@nestjs/common';
import type { TransactionContext } from '../db/unit-of-work.js';

export interface AccountErasure {
  readonly userId: string;
  readonly requestedAt: Date;
}

export interface PersonalDataParticipant {
  read(tx: TransactionContext, userId: string): Promise<Record<string, unknown>>;
  erase(tx: TransactionContext, account: AccountErasure): Promise<void>;
}

/** Owners register before the API serves requests or workers consume events. */
@Injectable()
export class PersonalDataRegistry {
  private readonly participants = new Map<string, PersonalDataParticipant>();

  register(module: string, participant: PersonalDataParticipant): void {
    if (this.participants.has(module))
      throw new Error('Registro de privacidad duplicado: ' + module);
    this.participants.set(module, participant);
  }

  async export(
    tx: TransactionContext,
    userId: string,
  ): Promise<Record<string, Record<string, unknown>>> {
    const entries = await Promise.all(
      [...this.participants].map(
        async ([module, participant]) => [module, await participant.read(tx, userId)] as const,
      ),
    );
    return Object.fromEntries(entries);
  }

  /** The caller commits the participants' writes together; retries cannot leave a half-erased account. */
  async erase(tx: TransactionContext, account: AccountErasure): Promise<void> {
    for (const participant of this.participants.values()) await participant.erase(tx, account);
  }
}
