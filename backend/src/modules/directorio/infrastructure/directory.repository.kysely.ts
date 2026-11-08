import { Inject, Injectable } from '@nestjs/common';
import { AccountAccess } from '../../../shared/auth/account-access.js';
import { type Kysely, type Selectable, sql } from 'kysely';
import { KYSELY } from '../../../shared/db/connection.js';
import { asJsonb, asKysely } from '../../../shared/db/unit-of-work.kysely.js';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import type { Category, DirectoryRepository } from '../application/ports.js';
import { ProviderProfile } from '../domain/provider-profile.js';
import { Service, type ServiceProps } from '../domain/service.js';
import type { DirectoryTables, ServicesTable } from './tables.js';

type ServiceRow = Selectable<ServicesTable> & { private_lat: number; private_lng: number };

function toService(row: ServiceRow): Service {
  return Service.restore({
    id: row.id,
    providerId: row.proveedor_id,
    zoneId: row.zona_id,
    categoryId: row.categoria_id,
    title: row.titulo,
    description: row.descripcion,
    location: { lat: row.private_lat, lng: row.private_lng },
    publicLocation: { lat: row.lat_publica, lng: row.lng_publica },
    showExactLocation: row.muestra_ubicacion_exacta,
    coverageRadiusMeters: row.radio_cobertura_m,
    availableInEmergency: row.disponible_en_emergencia,
    attributes: row.atributos,
    reviewCount: row.total_resenas,
    ratingSum: row.suma_calificaciones,
    average: Number(row.promedio),
    rankingScore: Number(row.puntaje_ranking),
    endorsementCount: row.total_vistos_buenos,
    zoneEndorsementCount: row.vistos_buenos_de_la_zona,
    version: row.version,
    createdAt: row.creado_en,
    updatedAt: row.actualizado_en,
    deletedAt: row.eliminado_en,
    hiddenAt: row.oculto_en,
  });
}

function editableValues(service: Service) {
  const data = service.snapshot();
  return {
    categoria_id: data.categoryId,
    titulo: data.title,
    descripcion: data.description,
    ubicacion: sql`ST_SetSRID(ST_MakePoint(${data.location.lng}, ${data.location.lat}), 4326)::geography`,
    lat_publica: data.publicLocation.lat,
    lng_publica: data.publicLocation.lng,
    muestra_ubicacion_exacta: data.showExactLocation,
    radio_cobertura_m: data.coverageRadiusMeters,
    disponible_en_emergencia: data.availableInEmergency,
    atributos: asJsonb(data.attributes),
    version: data.version,
    actualizado_en: data.updatedAt,
    eliminado_en: data.deletedAt,
  };
}

@Injectable()
export class KyselyDirectoryRepository implements DirectoryRepository {
  constructor(
    @Inject(KYSELY) private readonly db: Kysely<DirectoryTables>,
    private readonly accounts: AccountAccess,
  ) {}

  async listCategories(): Promise<Category[]> {
    const rows = await this.db
      .selectFrom('directorio.categorias')
      .select(['id', 'nombre', 'icono', 'util_en_emergencia', 'orden'])
      .orderBy('orden')
      .orderBy('id')
      .execute();
    return rows.map((row) => ({
      id: row.id,
      name: row.nombre,
      icon: row.icono,
      usefulInEmergency: row.util_en_emergencia,
      order: row.orden,
    }));
  }

  async categoryExists(transaction: TransactionContext, id: string): Promise<boolean> {
    return (
      (await asKysely<DirectoryTables>(transaction)
        .selectFrom('directorio.categorias')
        .select('id')
        .where('id', '=', id)
        .executeTakeFirst()) !== undefined
    );
  }

  async lockProvider(transaction: TransactionContext, id: string): Promise<void> {
    await sql`SELECT pg_advisory_xact_lock(hashtextextended(${`directorio:proveedor:${id}`}, 0))`.execute(
      asKysely(transaction),
    );
  }

  async findProvider(transaction: TransactionContext, id: string): Promise<ProviderProfile | null> {
    const row = await asKysely<DirectoryTables>(transaction)
      .selectFrom('directorio.proveedores')
      .selectAll()
      .where('id', '=', id)
      .executeTakeFirst();
    return row
      ? ProviderProfile.restore({
          id: row.id,
          zoneId: row.zona_id,
          publicName: row.nombre_publico,
          description: row.descripcion,
          createdAt: row.creado_en,
          updatedAt: row.actualizado_en,
          deletedAt: row.eliminado_en,
          hiddenAt: row.oculto_en,
        })
      : null;
  }

  async saveProvider(transaction: TransactionContext, provider: ProviderProfile): Promise<void> {
    const data = provider.snapshot();
    await this.accounts.requireActiveWrite(transaction, data.id);
    await asKysely<DirectoryTables>(transaction)
      .insertInto('directorio.proveedores')
      .values({
        id: data.id,
        zona_id: data.zoneId,
        nombre_publico: data.publicName,
        descripcion: data.description,
        creado_en: data.createdAt,
        actualizado_en: data.updatedAt,
      })
      .onConflict((conflict) =>
        conflict.column('id').doUpdateSet({
          zona_id: data.zoneId,
          nombre_publico: data.publicName,
          descripcion: data.description,
          actualizado_en: data.updatedAt,
        }),
      )
      .execute();
  }

  async findService(transaction: TransactionContext, id: string): Promise<Service | null> {
    const row = await asKysely<DirectoryTables>(transaction)
      .selectFrom('directorio.servicios')
      .selectAll()
      .select([
        sql<number>`ST_Y(ubicacion::geometry)`.as('private_lat'),
        sql<number>`ST_X(ubicacion::geometry)`.as('private_lng'),
      ])
      .where('id', '=', id)
      .executeTakeFirst();
    return row ? toService(row) : null;
  }

  async insertService(transaction: TransactionContext, service: Service): Promise<boolean> {
    const data = service.snapshot();
    await this.accounts.requireActiveWrite(transaction, data.providerId);
    const inserted = await asKysely<DirectoryTables>(transaction)
      .insertInto('directorio.servicios')
      .values({
        ...editableValues(service),
        id: data.id,
        proveedor_id: data.providerId,
        zona_id: data.zoneId,
        creado_en: data.createdAt,
      })
      .onConflict((conflict) => conflict.column('id').doNothing())
      .returning('id')
      .executeTakeFirst();
    return inserted !== undefined;
  }

  async updateService(
    transaction: TransactionContext,
    service: Service,
    previousVersion: number,
  ): Promise<boolean> {
    await this.accounts.requireActiveWrite(transaction, service.snapshot().providerId);
    const updated = await asKysely<DirectoryTables>(transaction)
      .updateTable('directorio.servicios')
      .set(editableValues(service))
      .where('id', '=', service.id)
      .where('version', '=', previousVersion)
      .where('eliminado_en', 'is', null)
      .executeTakeFirst();
    return Number(updated.numUpdatedRows) === 1;
  }

  async listPublicServices(
    transaction: TransactionContext,
    providerId: string,
    zoneId: string,
  ): Promise<ServiceProps[]> {
    const rows = await asKysely<DirectoryTables>(transaction)
      .selectFrom('directorio.servicios')
      .selectAll()
      .select([
        sql<number>`ST_Y(ubicacion::geometry)`.as('private_lat'),
        sql<number>`ST_X(ubicacion::geometry)`.as('private_lng'),
      ])
      .where('proveedor_id', '=', providerId)
      .where('zona_id', '=', zoneId)
      .where('eliminado_en', 'is', null)
      .where('oculto_en', 'is', null)
      .orderBy('id')
      .execute();
    return rows.map((row) => toService(row).snapshot());
  }

  async withdrawInZone(
    transaction: TransactionContext,
    providerId: string,
    zoneId: string,
    now: Date,
  ): Promise<void> {
    await asKysely<DirectoryTables>(transaction)
      .updateTable('directorio.servicios')
      .set((eb) => ({ eliminado_en: now, actualizado_en: now, version: eb('version', '+', 1) }))
      .where('proveedor_id', '=', providerId)
      .where('zona_id', '=', zoneId)
      .where('eliminado_en', 'is', null)
      .execute();
  }
}
