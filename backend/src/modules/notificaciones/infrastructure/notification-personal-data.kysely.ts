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
export class NotificationPersonalData implements OnModuleInit, PersonalDataParticipant {
  constructor(private readonly registry: PersonalDataRegistry) {}

  onModuleInit(): void {
    this.registry.register('notificaciones', this);
  }

  async read(tx: TransactionContext, userId: string) {
    const db = asKysely(tx);
    const [devices, deliveries] = await Promise.all([
      sql`SELECT id, plataforma, creado_en, actualizado_en, dado_de_baja_en
        FROM notificaciones.dispositivos WHERE usuario_id = ${userId} ORDER BY creado_en, id`.execute(
        db,
      ),
      sql`SELECT aviso_id, estado FROM notificaciones.entregas_aviso
        WHERE usuario_id = ${userId} ORDER BY aviso_id`.execute(db),
    ]);
    return { dispositivos: devices.rows, entregas: deliveries.rows };
  }

  async erase(tx: TransactionContext, { userId }: AccountErasure): Promise<void> {
    const db = asKysely(tx);
    await sql`DELETE FROM notificaciones.entregas_aviso WHERE usuario_id = ${userId}`.execute(db);
    await sql`DELETE FROM notificaciones.dispositivos WHERE usuario_id = ${userId}`.execute(db);
  }
}
