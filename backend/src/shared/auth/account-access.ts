import { Injectable } from '@nestjs/common';
import type { TransactionContext } from '../db/unit-of-work.js';
import { AuthenticationFailure } from '../domain/errors.js';
import type { Actor } from './actor.js';

interface AccessReader {
  resolve(actor: Actor): Promise<Actor | null>;
  lockActive(tx: TransactionContext, id: string): Promise<boolean>;
  lockStates(tx: TransactionContext, ids: readonly string[]): Promise<ReadonlyMap<string, boolean>>;
}

/** Identity owns account state; the global guard only depends on this shared port. */
@Injectable()
export class AccountAccess {
  private reader?: AccessReader;

  register(reader: AccessReader): void {
    if (this.reader) throw new Error('El lector de cuentas ya está registrado.');
    this.reader = reader;
  }

  resolve(actor: Actor): Promise<Actor | null> {
    if (!this.reader) throw new Error('Falta el lector de cuentas.');
    return this.reader.resolve(actor);
  }

  async requireActiveWrite(tx: TransactionContext, userId: string): Promise<void> {
    if (!this.reader) throw new Error('Falta el lector de cuentas.');
    if (!(await this.reader.lockActive(tx, userId))) {
      throw new AuthenticationFailure('sesion_revocada', 'La cuenta ya no está activa.');
    }
  }

  lockStates(
    tx: TransactionContext,
    ids: readonly string[],
  ): Promise<ReadonlyMap<string, boolean>> {
    if (!this.reader) throw new Error('Falta el lector de cuentas.');
    return this.reader.lockStates(tx, ids);
  }
}
