import { Injectable, type OnModuleInit } from '@nestjs/common';
import { sql } from 'kysely';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import { asKysely } from '../../../shared/db/unit-of-work.kysely.js';
import {
  type AccountErasure,
  PersonalDataRegistry,
  type PersonalDataParticipant,
} from '../../../shared/privacy/personal-data.registry.js';
import type { SolidarityTables } from './tables.js';

@Injectable()
export class SolidarityPersonalData implements OnModuleInit, PersonalDataParticipant {
  constructor(private readonly registry: PersonalDataRegistry) {}

  onModuleInit(): void {
    this.registry.register('solidaridad', this);
  }

  async read(tx: TransactionContext, userId: string) {
    const db = asKysely<SolidarityTables>(tx);
    const [publicaciones, favoresTomados] = await Promise.all([
      db
        .selectFrom('solidaridad.publicaciones')
        .select([
          'id',
          'zona_id',
          'tipo',
          'categoria',
          'titulo',
          'descripcion',
          'lat',
          'lng',
          'estado',
          'version',
          'vence_en',
          'creado_en',
          'actualizado_en',
          'eliminado_en',
        ])
        .where('autor_id', '=', userId)
        .orderBy('creado_en')
        .orderBy('id')
        .execute(),
      db
        .selectFrom('solidaridad.publicaciones')
        .select(['id', 'estado', 'actualizado_en'])
        .where('tomada_por_id', '=', userId)
        .orderBy('actualizado_en')
        .orderBy('id')
        .execute(),
    ]);
    return { publicaciones, favoresTomados };
  }

  async erase(tx: TransactionContext, { userId, requestedAt }: AccountErasure): Promise<void> {
    const db = asKysely<SolidarityTables>(tx);
    await db
      .updateTable('solidaridad.publicaciones')
      .set((eb) => ({
        titulo: 'Publicación retirada',
        descripcion: null,
        categoria: 'retirada',
        lat: null,
        lng: null,
        ubicacion: null,
        tomada_por_id: null,
        estado: 'cancelada',
        eliminado_en: eb.fn.coalesce('eliminado_en', eb.val(requestedAt)),
        actualizado_en: requestedAt,
        version: eb('version', '+', 1),
      }))
      .where('autor_id', '=', userId)
      .execute();
    await db
      .updateTable('solidaridad.publicaciones')
      .set((eb) => ({
        tomada_por_id: null,
        actualizado_en: requestedAt,
        version: eb('version', '+', 1),
        estado: sql`CASE WHEN estado = 'en_curso' THEN 'abierta' ELSE estado END`,
      }))
      .where('tomada_por_id', '=', userId)
      .execute();
  }
}
