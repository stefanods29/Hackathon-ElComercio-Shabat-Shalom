import { Injectable, type OnModuleInit } from '@nestjs/common';
import { sql } from 'kysely';
import type { SharedTables } from '../db/shared-tables.js';
import type { TransactionContext } from '../db/unit-of-work.js';
import { asKysely } from '../db/unit-of-work.kysely.js';
import {
  type AccountErasure,
  PersonalDataRegistry,
  type PersonalDataParticipant,
} from './personal-data.registry.js';

@Injectable()
export class SharedPersonalData implements OnModuleInit, PersonalDataParticipant {
  constructor(private readonly registry: PersonalDataRegistry) {}

  onModuleInit(): void {
    this.registry.register('compartido', this);
  }

  async read(tx: TransactionContext, userId: string) {
    const solicitudes = await asKysely<SharedTables>(tx)
      .selectFrom('compartido.idempotencia')
      .select(['metodo', 'ruta', 'estado', 'codigo_http', 'creada_en', 'expira_en'])
      .where('alcance', '=', userId)
      .orderBy('creada_en')
      .execute();
    return { solicitudes };
  }

  async erase(tx: TransactionContext, { userId }: AccountErasure): Promise<void> {
    await asKysely<SharedTables>(tx)
      .deleteFrom('compartido.idempotencia')
      .where((eb) =>
        eb.or([
          eb('alcance', '=', userId),
          // A cached response from another actor may contain this neighbor's public data.
          sql<boolean>`jsonb_path_exists(cuerpo_respuesta, '$.** ? (@ == $usuario)', jsonb_build_object('usuario', ${userId}::text))`,
        ]),
      )
      .execute();
  }
}
