import { Inject, Injectable } from '@nestjs/common';
import { type Kysely, type Selectable, sql } from 'kysely';
import { AuthenticationFailure } from '../../../shared/domain/errors.js';
import { ROLES, type Role } from '../../../shared/auth/actor.js';
import { KYSELY } from '../../../shared/db/connection.js';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import { asKysely } from '../../../shared/db/unit-of-work.kysely.js';
import type { RegisteredUser, UserRepository } from '../application/ports.js';
import type { IdentityTables, UsersTable } from './tables.js';

function toUser(row: Selectable<UsersTable>): RegisteredUser {
  if (row.telefono === null) throw new Error('Una cuenta activa debe tener teléfono.');
  return {
    id: row.id,
    phone: row.telefono,
    displayName: row.nombre_visible,
    zoneId: row.zona_id,
    trustLevel: row.nivel_confianza,
    roles: row.roles.filter((role): role is Role => (ROLES as readonly string[]).includes(role)),
  };
}

@Injectable()
export class KyselyUserRepository implements UserRepository {
  constructor(@Inject(KYSELY) private readonly db: Kysely<IdentityTables>) {}

  async findByPhone(phone: string): Promise<RegisteredUser | null> {
    const row = await this.db
      .selectFrom('identidad.usuarios')
      .selectAll()
      .where('telefono', '=', phone)
      .where('eliminado_en', 'is', null)
      .executeTakeFirst();
    return row ? toUser(row) : null;
  }

  async findById(id: string, transaction?: TransactionContext): Promise<RegisteredUser | null> {
    const db = transaction ? asKysely<IdentityTables>(transaction) : this.db;
    const row = await db
      .selectFrom('identidad.usuarios')
      .selectAll()
      .where('id', '=', id)
      .where('eliminado_en', 'is', null)
      .executeTakeFirst();
    return row ? toUser(row) : null;
  }

  async findOrCreateByPhone(
    transaction: TransactionContext,
    phone: string,
  ): Promise<RegisteredUser> {
    const db = asKysely<IdentityTables>(transaction);
    const inserted = await db
      .insertInto('identidad.usuarios')
      .values({
        telefono: phone,
        nombre_visible: 'Vecino nuevo',
        zona_id: null,
        nivel_confianza: 0,
        roles: [],
        actualizado_en: sql`now()`,
      })
      .onConflict((conflict) => conflict.column('telefono').doNothing())
      .returningAll()
      .executeTakeFirst();
    if (inserted) return toUser(inserted);

    const existing = await db
      .selectFrom('identidad.usuarios')
      .selectAll()
      .where('telefono', '=', phone)
      .where('eliminado_en', 'is', null)
      .executeTakeFirst();
    if (!existing) {
      throw new AuthenticationFailure('sesion_revocada', 'La cuenta ya no está activa.');
    }
    return toUser(existing);
  }
}
