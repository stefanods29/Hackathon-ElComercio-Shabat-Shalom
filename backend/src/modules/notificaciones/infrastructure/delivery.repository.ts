import { Inject, Injectable } from '@nestjs/common';
import { createHash } from 'node:crypto';
import { type Kysely, sql } from 'kysely';
import { KYSELY } from '../../../shared/db/connection.js';
import type {
  DeliveryRequest,
  NotificationDelivery,
  NotificationPort,
  PushMessage,
} from '../application/ports.js';

@Injectable()
export class DeliveryRepository implements NotificationDelivery {
  constructor(@Inject(KYSELY) private readonly db: Kysely<unknown>) {}

  async deliver(
    job: DeliveryRequest,
    message: PushMessage,
    push: NotificationPort,
  ): Promise<void> {
    const fingerprint = createHash('sha256')
      .update(JSON.stringify([job.destino, message]))
      .digest('hex');
    await this.db.transaction().execute(async (trx) => {
      const inserted =
        await sql`INSERT INTO notificaciones.avisos_enviados (aviso_id, huella, plantilla, estado)
        VALUES (${job.avisoId}::uuid, ${fingerprint}, ${job.plantilla}, 'enviando')
        ON CONFLICT DO NOTHING RETURNING aviso_id`.execute(trx);
      const saved = await sql<{ huella: string }>`SELECT huella FROM notificaciones.avisos_enviados
        WHERE aviso_id = ${job.avisoId}::uuid FOR UPDATE`.execute(trx);
      if (saved.rows[0]?.huella !== fingerprint)
        throw new Error('El identificador del aviso ya tiene otro contenido');
      if (inserted.rows.length === 0) return;
      if (job.destino.tipo === 'usuario') {
        await sql`INSERT INTO notificaciones.entregas_aviso (aviso_id, destinatario, usuario_id)
          SELECT ${job.avisoId}::uuid, id::text, usuario_id FROM notificaciones.dispositivos
          WHERE usuario_id = ${job.destino.usuarioId}::uuid AND dado_de_baja_en IS NULL`.execute(
          trx,
        );
      } else {
        await sql`INSERT INTO notificaciones.entregas_aviso (aviso_id, destinatario)
          VALUES (${job.avisoId}::uuid, ${'zona-' + job.destino.zonaId})`.execute(trx);
      }
    });
    const targets = await sql<{
      destinatario: string;
    }>`SELECT destinatario FROM notificaciones.entregas_aviso
      WHERE aviso_id = ${job.avisoId}::uuid AND estado = 'pendiente' ORDER BY destinatario`.execute(
      this.db,
    );
    for (const target of targets.rows) {
      // Commit each recipient separately: a later failure must not repeat successful deliveries.
      await this.db.transaction().execute(async (trx) => {
        const delivery = await sql<{
          estado: string;
          usuario_id: string | null;
        }>`SELECT estado, usuario_id
          FROM notificaciones.entregas_aviso WHERE aviso_id = ${job.avisoId}::uuid
          AND destinatario = ${target.destinatario} FOR UPDATE`.execute(trx);
        const row = delivery.rows[0];
        if (!row || row.estado !== 'pendiente') return;
        let state = 'enviado';
        if (job.destino.tipo === 'zona') {
          await push.sendToTopic(target.destinatario, message);
        } else {
          // Lock also serializes sign-out/reassignment with sending to the previous owner.
          const devices = await sql<{
            token: string;
            usuario_id: string;
            dado_de_baja_en: Date | null;
          }>`
            SELECT token, usuario_id, dado_de_baja_en FROM notificaciones.dispositivos
            WHERE id = ${target.destinatario}::uuid FOR UPDATE`.execute(trx);
          const device = devices.rows[0];
          if (!device || device.dado_de_baja_en || device.usuario_id !== row.usuario_id) {
            state = 'omitido';
          } else if ((await push.sendToToken(device.token, message)) === 'invalid_token') {
            await sql`UPDATE notificaciones.dispositivos SET dado_de_baja_en = now(), actualizado_en = now()
              WHERE id = ${target.destinatario}::uuid`.execute(trx);
            state = 'omitido';
          }
        }
        await sql`UPDATE notificaciones.entregas_aviso SET estado = ${state}
          WHERE aviso_id = ${job.avisoId}::uuid AND destinatario = ${target.destinatario}`.execute(
          trx,
        );
      });
    }
    await sql`UPDATE notificaciones.avisos_enviados SET estado = 'enviado'
      WHERE aviso_id = ${job.avisoId}::uuid AND NOT EXISTS (
        SELECT 1 FROM notificaciones.entregas_aviso WHERE aviso_id = ${job.avisoId}::uuid AND estado = 'pendiente'
      )`.execute(this.db);
  }

  async deliveredCount(avisoId: string): Promise<number> {
    const result = await sql<{ total: number }>`SELECT count(*)::int AS total
      FROM notificaciones.entregas_aviso
      WHERE aviso_id = ${avisoId}::uuid AND estado = 'enviado'`.execute(this.db);
    return result.rows[0]?.total ?? 0;
  }
}
