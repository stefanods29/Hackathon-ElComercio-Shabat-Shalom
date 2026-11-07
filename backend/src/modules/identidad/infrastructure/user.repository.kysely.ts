import { Inject, Injectable } from '@nestjs/common';
import type { Kysely, Selectable } from 'kysely';
import { ROLES, type Role } from '../../../shared/auth/actor.js';
import { KYSELY } from '../../../shared/db/connection.js';
import type { RegisteredUser, UserRepository } from '../application/ports.js';
import type { IdentityTables, UsersTable } from './tables.js';

function toUser(row: Selectable<UsersTable>): RegisteredUser {
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

  async findById(id: string): Promise<RegisteredUser | null> {
    const row = await this.db
      .selectFrom('identidad.usuarios')
      .selectAll()
      .where('id', '=', id)
      .where('eliminado_en', 'is', null)
      .executeTakeFirst();
    return row ? toUser(row) : null;
  }
}
