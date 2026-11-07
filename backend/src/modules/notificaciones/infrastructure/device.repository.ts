import { Inject, Injectable } from '@nestjs/common';
import { createHash } from 'node:crypto';
import { type Kysely, sql } from 'kysely';
import { KYSELY } from '../../../shared/db/connection.js';

import type { DeviceRegistration, DeviceRegistrationResult } from '../application/ports.js';

@Injectable()
export class DeviceRepository implements DeviceRegistration {
  constructor(@Inject(KYSELY) private readonly db: Kysely<unknown>) {}

  async register(
    userId: string,
    token: string,
    platform: 'android' | 'ios',
  ): Promise<DeviceRegistrationResult> {
    const hash = createHash('sha256').update(token).digest();
    const result = await sql<{ id: string; plataforma: 'android' | 'ios'; creado_en: Date }>`
      INSERT INTO notificaciones.dispositivos (usuario_id, token, token_hash, plataforma)
      VALUES (${userId}::uuid, ${token}, ${hash}, ${platform})
      ON CONFLICT (token_hash) DO UPDATE SET usuario_id = EXCLUDED.usuario_id,
        plataforma = EXCLUDED.plataforma, actualizado_en = now(), dado_de_baja_en = NULL
      WHERE notificaciones.dispositivos.token = EXCLUDED.token
      RETURNING id, plataforma, creado_en
    `.execute(this.db);
    const device = result.rows[0];
    if (!device) throw new Error('No se pudo registrar el dispositivo');
    return {
      id: device.id,
      plataforma: device.plataforma,
      registradoEn: device.creado_en.toISOString(),
    };
  }

  async unregister(userId: string, token: string): Promise<void> {
    await sql`UPDATE notificaciones.dispositivos SET dado_de_baja_en = now(), actualizado_en = now()
      WHERE usuario_id = ${userId}::uuid AND token_hash = ${createHash('sha256').update(token).digest()}
        AND token = ${token} AND dado_de_baja_en IS NULL`.execute(this.db);
  }
}
