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
export class EmergencyPersonalData implements OnModuleInit, PersonalDataParticipant {
  constructor(private readonly registry: PersonalDataRegistry) {}

  onModuleInit(): void {
    this.registry.register('emergencias', this);
  }

  async read(tx: TransactionContext, userId: string) {
    const db = asKysely(tx);
    await sql`INSERT INTO emergencias.auditoria(usuario_id,pedido_id,rol,accion,ocurrido_en)
      SELECT ${userId},id,'vecino','exportacion_propia',now() FROM emergencias.pedidos_ayuda WHERE autor_id = ${userId}`.execute(
      db,
    );
    const requests = await sql`SELECT p.id,p.necesidad,p.prioridad,p.estado,p.creado_en,p.vence_en,
      d.descripcion,d.lat,d.lng FROM emergencias.pedidos_ayuda p
      LEFT JOIN emergencias.detalles_pedidos d ON d.pedido_id = p.id
      WHERE p.autor_id = ${userId} ORDER BY p.id`.execute(db);
    const grants =
      await sql`SELECT id,rol,zona_id,dni_revisado_en,capacitacion_en,confidencialidad_en,
      vence_en,revocada_en FROM emergencias.habilitaciones WHERE usuario_id = ${userId} ORDER BY id`.execute(
        db,
      );
    const result = await sql`SELECT id, pedido_id, asignada_en, finalizada_en
      FROM emergencias.asignaciones WHERE usuario_id = ${userId} ORDER BY asignada_en, id`.execute(
      db,
    );
    return { pedidos: requests.rows, habilitaciones: grants.rows, asignaciones: result.rows };
  }

  async erase(tx: TransactionContext, { userId, requestedAt }: AccountErasure): Promise<void> {
    const db = asKysely(tx);
    const owned = await sql<{ id: string }>`SELECT id FROM emergencias.pedidos_ayuda
      WHERE autor_id = ${userId} FOR UPDATE`.execute(db);
    await sql`DELETE FROM emergencias.agregados_celda WHERE zona_id IN (
      SELECT zona_id FROM emergencias.pedidos_ayuda WHERE autor_id = ${userId})`.execute(db);
    for (const { id } of owned.rows) {
      await sql`DELETE FROM emergencias.detalles_pedidos WHERE pedido_id = ${id}`.execute(db);
      await sql`DELETE FROM emergencias.asignaciones WHERE pedido_id = ${id}`.execute(db);
      await sql`UPDATE emergencias.historial_pedidos SET usuario_id = NULL,motivo = NULL WHERE pedido_id = ${id}`.execute(
        db,
      );
      await sql`UPDATE emergencias.escalamientos SET usuario_id = NULL WHERE pedido_id = ${id}`.execute(
        db,
      );
    }
    await sql`UPDATE emergencias.pedidos_ayuda SET autor_id = NULL,huella = NULL,celda = NULL,
      detalle = 'Pedido anonimizado',anonimizado_en = ${requestedAt},escalar_en = NULL,
      estado = CASE WHEN cerrado_en IS NULL THEN 'cerrado_sin_atender' ELSE estado END,
      cerrado_en = coalesce(cerrado_en,${requestedAt}),version = version + 1 WHERE autor_id = ${userId}`.execute(
      db,
    );
    await sql`DELETE FROM emergencias.asignaciones WHERE usuario_id = ${userId}`.execute(db);
    await sql`DELETE FROM emergencias.miembros_grupo WHERE usuario_id = ${userId}`.execute(db);
    await sql`DELETE FROM emergencias.turnos WHERE usuario_id = ${userId}`.execute(db);
    await sql`DELETE FROM emergencias.habilitaciones WHERE usuario_id = ${userId}`.execute(db);
    await sql`UPDATE emergencias.habilitaciones SET revisada_por = NULL WHERE revisada_por = ${userId}`.execute(
      db,
    );
    await sql`UPDATE emergencias.eventos SET activado_por = NULL WHERE activado_por = ${userId}`.execute(
      db,
    );
    await sql`UPDATE emergencias.historial_pedidos SET usuario_id = NULL,motivo = NULL WHERE usuario_id = ${userId}`.execute(
      db,
    );
    await sql`UPDATE emergencias.escalamientos SET usuario_id = NULL WHERE usuario_id = ${userId}`.execute(
      db,
    );
    await sql`UPDATE emergencias.auditoria SET usuario_id = NULL WHERE usuario_id = ${userId}`.execute(
      db,
    );
    const confirmed = await sql<{ id: string }>`DELETE FROM emergencias.confirmaciones_recursos
      WHERE usuario_id = ${userId} RETURNING recurso_id AS id`.execute(db);
    for (const { id } of confirmed.rows) {
      await sql`UPDATE emergencias.recursos_criticos r SET confirmaciones = (
        SELECT count(*) FROM emergencias.confirmaciones_recursos c WHERE c.recurso_id = r.id),version = version + 1
        WHERE r.id = ${id}`.execute(db);
      await sql`UPDATE emergencias.recursos_criticos SET verificacion = 'sin_verificar'
        WHERE id = ${id} AND confirmaciones = 0 AND verificacion = 'confirmado'`.execute(db);
      await sql`UPDATE emergencias.recursos_publicos p SET confirmaciones = r.confirmaciones,
        verificacion = r.verificacion,version = r.version FROM emergencias.recursos_criticos r WHERE p.id = r.id AND r.id = ${id}`.execute(
        db,
      );
    }
    await sql`UPDATE emergencias.recursos_criticos SET reportante_id = NULL WHERE reportante_id = ${userId}`.execute(
      db,
    );
  }
}
