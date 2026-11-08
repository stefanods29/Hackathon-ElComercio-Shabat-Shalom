import { Inject, Injectable, type OnModuleInit } from '@nestjs/common';
import { type Kysely, sql } from 'kysely';
import { validate as isUuid } from 'uuid';
import { AccountAccess } from '../../../shared/auth/account-access.js';
import type { Actor } from '../../../shared/auth/actor.js';
import { KYSELY } from '../../../shared/db/connection.js';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import { asKysely } from '../../../shared/db/unit-of-work.kysely.js';
import {
  type AccountErasure,
  PersonalDataRegistry,
  type PersonalDataParticipant,
} from '../../../shared/privacy/personal-data.registry.js';
import type { AccountPrivacyStore } from '../application/account-privacy-store.js';
import type { IdentityTables } from './tables.js';

@Injectable()
export class KyselyIdentityPersonalData
  implements OnModuleInit, PersonalDataParticipant, AccountPrivacyStore
{
  constructor(
    @Inject(KYSELY) private readonly db: Kysely<IdentityTables>,
    private readonly registry: PersonalDataRegistry,
    private readonly access: AccountAccess,
  ) {}

  onModuleInit(): void {
    this.registry.register('identidad', this);
    this.access.register({
      resolve: (actor) => this.resolveAccess(actor),
      lockActive: (tx, id) => this.lockActive(tx, id),
      lockStates: (tx, ids) => this.lockStates(tx, ids),
    });
  }

  async resolveAccess(actor: Actor): Promise<Actor | null> {
    if (!isUuid(actor.id)) return null;
    const user = await this.db
      .selectFrom('identidad.usuarios')
      .select(['zona_id', 'nivel_confianza'])
      .where('id', '=', actor.id)
      .where('eliminado_en', 'is', null)
      .executeTakeFirst();
    if (!user) return null;
    // Old JWTs may not retain old-zone privileges; promotions appear in the next issued token.
    if (user.zona_id !== actor.zoneId) return { ...actor, zoneId: null, trustLevel: 0 };
    return { ...actor, trustLevel: Math.min(actor.trustLevel, user.nivel_confianza) };
  }

  private async lockActive(tx: TransactionContext, id: string): Promise<boolean> {
    const row = await asKysely<IdentityTables>(tx)
      .selectFrom('identidad.usuarios')
      .select('id')
      .where('id', '=', id)
      .where('eliminado_en', 'is', null)
      .forShare()
      .executeTakeFirst();
    return row !== undefined;
  }

  private async lockStates(
    tx: TransactionContext,
    ids: readonly string[],
  ): Promise<ReadonlyMap<string, boolean>> {
    if (!ids.length) return new Map();
    // A write that already holds this lock commits before the account can be marked deleted.
    const rows = await asKysely<IdentityTables>(tx)
      .selectFrom('identidad.usuarios')
      .select(['id', 'eliminado_en'])
      .where('id', 'in', ids)
      .orderBy('id')
      .forShare()
      .execute();
    return new Map(rows.map((row) => [row.id, row.eliminado_en === null]));
  }

  async markDeleted(tx: TransactionContext, userId: string, now: Date): Promise<boolean> {
    const result = await asKysely<IdentityTables>(tx)
      .updateTable('identidad.usuarios')
      .set({ eliminado_en: now, actualizado_en: now })
      .where('id', '=', userId)
      .where('eliminado_en', 'is', null)
      .executeTakeFirst();
    return result.numUpdatedRows > 0n;
  }

  async findPendingPhone(
    tx: TransactionContext,
    userId: string,
    lock = false,
  ): Promise<string | null> {
    const query = asKysely<IdentityTables>(tx)
      .selectFrom('identidad.usuarios')
      .select('telefono')
      .where('id', '=', userId)
      .where('eliminado_en', 'is not', null);
    const user = await (lock ? query.forUpdate() : query).executeTakeFirst();
    return user?.telefono ?? null;
  }

  async rectify(tx: TransactionContext, userId: string, name: string, now: Date): Promise<boolean> {
    const result = await asKysely<IdentityTables>(tx)
      .updateTable('identidad.usuarios')
      .set({ nombre_visible: name, actualizado_en: now })
      .where('id', '=', userId)
      .where('eliminado_en', 'is', null)
      .executeTakeFirst();
    return result.numUpdatedRows > 0n;
  }

  async read(tx: TransactionContext, userId: string) {
    const db = asKysely<IdentityTables>(tx);
    const [perfil, zona, consentimientos, presencias, avales, confirmaciones, sesiones] =
      await Promise.all([
        db
          .selectFrom('identidad.usuarios')
          .select([
            'id',
            'telefono',
            'nombre_visible',
            'nivel_confianza',
            'roles',
            'creado_en',
            'actualizado_en',
            'zona_elegida_en',
          ])
          .where('id', '=', userId)
          .executeTakeFirstOrThrow(),
        db
          .selectFrom('identidad.usuarios')
          .innerJoin('identidad.zonas', 'identidad.zonas.id', 'identidad.usuarios.zona_id')
          .select(['identidad.zonas.id', 'identidad.zonas.nombre', 'identidad.zonas.distrito'])
          .where('identidad.usuarios.id', '=', userId)
          .executeTakeFirst(),
        db
          .selectFrom('identidad.consentimientos')
          .select(['finalidad', 'version', 'aceptado', 'decidido_en'])
          .where('usuario_id', '=', userId)
          .orderBy('decidido_en')
          .orderBy('id')
          .execute(),
        db
          .selectFrom('identidad.presencias')
          .select([sql<string>`fecha::text`.as('fecha'), 'dentro_de_la_zona'])
          .where('usuario_id', '=', userId)
          .orderBy('fecha')
          .execute(),
        db
          .selectFrom('identidad.avales')
          .select([
            'zona_id',
            'creado_en',
            sql<boolean>`vecino_id = ${userId}::uuid`.as('recibido'),
          ])
          .where((eb) => eb.or([eb('vecino_id', '=', userId), eb('avalista_id', '=', userId)]))
          .orderBy('creado_en')
          .execute(),
        db
          .selectFrom('identidad.confirmaciones')
          .select(['zona_id', 'nivel', 'motivo', 'creada_en'])
          .where('vecino_id', '=', userId)
          .orderBy('creada_en')
          .execute(),
        db
          .selectFrom('identidad.sesiones')
          .select(['dispositivo', 'creada_en', 'expira_en', 'rotada_en', 'revocada_en', 'motivo'])
          .where('usuario_id', '=', userId)
          .orderBy('creada_en')
          .execute(),
      ]);
    const solicitudesOtp = perfil.telefono
      ? await db
          .selectFrom('identidad.codigos_otp')
          .select(['canal', 'ip', 'intentos', 'expira_en', 'usado_en', 'creado_en'])
          .where('telefono', '=', perfil.telefono)
          .orderBy('creado_en')
          .execute()
      : [];
    return {
      perfil: {
        id: perfil.id,
        telefono: perfil.telefono,
        nombreVisible: perfil.nombre_visible,
        nivel: perfil.nivel_confianza,
        roles: perfil.roles,
        creadoEn: perfil.creado_en,
        actualizadoEn: perfil.actualizado_en,
        zonaElegidaEn: perfil.zona_elegida_en,
      },
      zona: zona ?? null,
      consentimientos,
      presencias,
      avales,
      confirmaciones,
      sesiones,
      solicitudesOtp,
    };
  }

  async erase(tx: TransactionContext, { userId, requestedAt }: AccountErasure): Promise<void> {
    const db = asKysely<IdentityTables>(tx);
    const phone = await this.findPendingPhone(tx, userId);
    if (!phone) return;
    await db.deleteFrom('identidad.codigos_otp').where('telefono', '=', phone).execute();
    await db
      .deleteFrom('identidad.limites_otp')
      .where('ambito', '=', 'telefono')
      .where('identificador', '=', phone)
      .execute();
    await db.deleteFrom('identidad.sesiones').where('usuario_id', '=', userId).execute();
    await db.deleteFrom('identidad.consentimientos').where('usuario_id', '=', userId).execute();
    await db.deleteFrom('identidad.presencias').where('usuario_id', '=', userId).execute();
    await db
      .deleteFrom('identidad.avales')
      .where((eb) => eb.or([eb('vecino_id', '=', userId), eb('avalista_id', '=', userId)]))
      .execute();
    await db
      .deleteFrom('identidad.confirmaciones')
      .where((eb) => eb.or([eb('vecino_id', '=', userId), eb('moderador_id', '=', userId)]))
      .execute();
    await db
      .updateTable('identidad.usuarios')
      .set({
        telefono: null,
        nombre_visible: 'Cuenta eliminada',
        zona_id: null,
        zona_elegida_en: null,
        nivel_confianza: 0,
        roles: [],
        actualizado_en: requestedAt,
      })
      .where('id', '=', userId)
      .where('eliminado_en', 'is not', null)
      .execute();
  }
}
