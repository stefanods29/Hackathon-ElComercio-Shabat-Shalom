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
export class ModerationPersonalData implements OnModuleInit, PersonalDataParticipant {
  constructor(private readonly registry: PersonalDataRegistry) {}

  onModuleInit(): void {
    this.registry.register('moderacion', this);
  }

  async read(tx: TransactionContext, userId: string) {
    const db = asKysely(tx);
    const [reports, decisions, sanctions] = await Promise.all([
      sql`SELECT d.id, d.caso_id, c.tipo_contenido, c.contenido_id, d.motivo, d.detalle, d.creada_en
        FROM moderacion.denuncias d JOIN moderacion.casos c ON c.id = d.caso_id
        WHERE d.denunciante_id = ${userId} ORDER BY d.creada_en, d.id`.execute(db),
      sql`SELECT caso_id, accion, decidida_en FROM moderacion.decisiones
        WHERE moderador_id = ${userId} ORDER BY decidida_en, id`.execute(db),
      sql`SELECT desde, hasta FROM moderacion.sanciones WHERE usuario_id = ${userId} ORDER BY desde, id`.execute(
        db,
      ),
    ]);
    return { denuncias: reports.rows, decisiones: decisions.rows, sanciones: sanctions.rows };
  }

  async erase(tx: TransactionContext, { userId }: AccountErasure): Promise<void> {
    const db = asKysely(tx);
    await sql`DELETE FROM moderacion.denuncias WHERE denunciante_id = ${userId}`.execute(db);
    await sql`UPDATE moderacion.denuncias d SET detalle = NULL FROM moderacion.casos c
      WHERE c.id = d.caso_id AND c.autor_id = ${userId}`.execute(db);
    await sql`UPDATE moderacion.decisiones d SET motivo = 'Cuenta eliminada',
        moderador_id = CASE WHEN d.moderador_id = ${userId}::uuid THEN NULL ELSE d.moderador_id END
      FROM moderacion.casos c WHERE c.id = d.caso_id
        AND (c.autor_id = ${userId} OR d.moderador_id = ${userId})`.execute(db);
    await sql`UPDATE moderacion.casos SET autor_id = NULL WHERE autor_id = ${userId}`.execute(db);
    await sql`DELETE FROM moderacion.sanciones WHERE usuario_id = ${userId}`.execute(db);
  }
}
