import { Inject, Injectable, type OnModuleInit } from '@nestjs/common';
import { sql } from 'kysely';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import { asKysely, asJsonb } from '../../../shared/db/unit-of-work.kysely.js';
import {
  type AccountErasure,
  PersonalDataRegistry,
  type PersonalDataParticipant,
} from '../../../shared/privacy/personal-data.registry.js';
import { DIRECTORY_REPOSITORY, type DirectoryRepository } from '../application/ports.js';
import type { DirectoryTables } from './tables.js';

@Injectable()
export class DirectoryPersonalData implements OnModuleInit, PersonalDataParticipant {
  constructor(
    private readonly registry: PersonalDataRegistry,
    @Inject(DIRECTORY_REPOSITORY) private readonly directory: DirectoryRepository,
  ) {}

  onModuleInit(): void {
    this.registry.register('directorio', this);
  }

  async read(tx: TransactionContext, userId: string) {
    const db = asKysely<DirectoryTables>(tx);
    const [proveedor, servicios] = await Promise.all([
      db
        .selectFrom('directorio.proveedores')
        .selectAll()
        .where('id', '=', userId)
        .executeTakeFirst(),
      db
        .selectFrom('directorio.servicios')
        .select([
          'id',
          'zona_id',
          'categoria_id',
          'titulo',
          'descripcion',
          'lat_publica',
          'lng_publica',
          'muestra_ubicacion_exacta',
          'radio_cobertura_m',
          'disponible_en_emergencia',
          'atributos',
          'creado_en',
          'actualizado_en',
          'eliminado_en',
          'oculto_en',
          'version',
          sql<number>`ST_Y(ubicacion::geometry)`.as('lat_privada'),
          sql<number>`ST_X(ubicacion::geometry)`.as('lng_privada'),
        ])
        .where('proveedor_id', '=', userId)
        .orderBy('creado_en')
        .orderBy('id')
        .execute(),
    ]);
    return { proveedor: proveedor ?? null, servicios };
  }

  async erase(tx: TransactionContext, { userId, requestedAt }: AccountErasure): Promise<void> {
    await this.directory.lockProvider(tx, userId);
    const db = asKysely<DirectoryTables>(tx);
    // Keep identifiers required by reviews and by existing sync records; erase the data behind them.
    await db
      .updateTable('directorio.servicios')
      .set((eb) => ({
        titulo: 'Servicio retirado',
        descripcion: null,
        atributos: asJsonb({}),
        ubicacion: sql`ST_SetSRID(ST_MakePoint(0, 0), 4326)::geography`,
        lat_publica: 0,
        lng_publica: 0,
        muestra_ubicacion_exacta: false,
        disponible_en_emergencia: false,
        eliminado_en: eb.fn.coalesce('eliminado_en', eb.val(requestedAt)),
        actualizado_en: requestedAt,
        version: eb('version', '+', 1),
      }))
      .where('proveedor_id', '=', userId)
      .execute();
    await db
      .updateTable('directorio.proveedores')
      .set((eb) => ({
        nombre_publico: 'Proveedor retirado',
        descripcion: null,
        eliminado_en: eb.fn.coalesce('eliminado_en', eb.val(requestedAt)),
        actualizado_en: requestedAt,
      }))
      .where('id', '=', userId)
      .execute();
  }
}
