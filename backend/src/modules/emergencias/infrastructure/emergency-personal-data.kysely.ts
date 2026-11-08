import { Injectable, type OnModuleInit } from '@nestjs/common';
import { sql } from 'kysely';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import { asKysely } from '../../../shared/db/unit-of-work.kysely.js';
import {
  type AccountErasure,
  PersonalDataRegistry,
  type PersonalDataParticipant,
} from '../../../shared/privacy/personal-data.registry.js';

@Injectable()
export class EmergencyPersonalData implements OnModuleInit, PersonalDataParticipant {
  constructor(private readonly registry: PersonalDataRegistry) {}

  onModuleInit(): void {
    this.registry.register('emergencias', this);
  }

  async read(tx: TransactionContext, userId: string) {
    const result = await sql`SELECT id, pedido_id, asignada_en, finalizada_en
      FROM emergencias.asignaciones WHERE usuario_id = ${userId} ORDER BY asignada_en, id`.execute(
      asKysely(tx),
    );
    return { asignaciones: result.rows };
  }

  async erase(tx: TransactionContext, { userId }: AccountErasure): Promise<void> {
    await sql`DELETE FROM emergencias.asignaciones WHERE usuario_id = ${userId}`.execute(
      asKysely(tx),
    );
  }
}
