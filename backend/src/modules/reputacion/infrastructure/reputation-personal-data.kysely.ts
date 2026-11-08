import { Inject, Injectable, type OnModuleInit } from '@nestjs/common';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import { asKysely } from '../../../shared/db/unit-of-work.kysely.js';
import { OUTBOX_WRITER, type OutboxWriter } from '../../../shared/outbox/outbox.js';
import {
  type AccountErasure,
  PersonalDataRegistry,
  type PersonalDataParticipant,
} from '../../../shared/privacy/personal-data.registry.js';
import { recalculationRequested } from '../application/reputation-events.js';
import type { ReputationTables } from './tables.js';

@Injectable()
export class ReputationPersonalData implements OnModuleInit, PersonalDataParticipant {
  constructor(
    private readonly registry: PersonalDataRegistry,
    @Inject(OUTBOX_WRITER) private readonly outbox: OutboxWriter,
  ) {}

  onModuleInit(): void {
    this.registry.register('reputacion', this);
  }

  async read(tx: TransactionContext, userId: string) {
    const db = asKysely<ReputationTables>(tx);
    const [resenas, fotos, vistosBuenos] = await Promise.all([
      db
        .selectFrom('reputacion.resenas')
        .selectAll()
        .where('autor_id', '=', userId)
        .orderBy('creado_en')
        .orderBy('id')
        .execute(),
      db
        .selectFrom('reputacion.resena_fotos')
        .innerJoin(
          'reputacion.resenas',
          'reputacion.resenas.id',
          'reputacion.resena_fotos.resena_id',
        )
        .selectAll('reputacion.resena_fotos')
        .where('reputacion.resenas.autor_id', '=', userId)
        .orderBy('reputacion.resena_fotos.resena_id')
        .orderBy('reputacion.resena_fotos.orden')
        .execute(),
      db
        .selectFrom('reputacion.vistos_buenos')
        .selectAll()
        .where('vecino_id', '=', userId)
        .orderBy('creado_en')
        .orderBy('id')
        .execute(),
    ]);
    return { resenas, fotos, vistosBuenos };
  }

  async erase(tx: TransactionContext, { userId, requestedAt }: AccountErasure): Promise<void> {
    const db = asKysely<ReputationTables>(tx);
    const authored = db
      .selectFrom('reputacion.resenas')
      .select('id')
      .where('autor_id', '=', userId);
    await db.deleteFrom('reputacion.resena_fotos').where('resena_id', 'in', authored).execute();
    await db.deleteFrom('reputacion.senales_resenas').where('resena_id', 'in', authored).execute();
    // Public ratings can remain without free text, photos or an identifiable author.
    await db
      .updateTable('reputacion.resenas')
      .set({ comentario: null, motivo_estado: null, actualizado_en: requestedAt })
      .where('autor_id', '=', userId)
      .where('estado', '=', 'publicada')
      .execute();
    await db
      .deleteFrom('reputacion.resenas')
      .where('autor_id', '=', userId)
      .where('estado', '<>', 'publicada')
      .execute();
    const removed = await db
      .deleteFrom('reputacion.vistos_buenos')
      .where('vecino_id', '=', userId)
      .returning('servicio_id')
      .execute();
    const affected = new Set(removed.map((row) => row.servicio_id));
    if (affected.size) {
      await this.outbox.record(
        tx,
        'reputacion',
        [...affected].map((id) => recalculationRequested(id, requestedAt)),
      );
    }
  }
}
