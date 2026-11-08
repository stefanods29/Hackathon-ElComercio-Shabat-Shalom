import { Inject, Injectable } from '@nestjs/common';
import { z } from 'zod';
import { APP_CONFIG, type AppConfig } from '../../../shared/config/app-config.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import type { OfficialAlert, OfficialAlertSource } from '../application/ports.js';

const feedSchema = z.strictObject({
  alertas: z
    .array(
      z.strictObject({
        id: z.string().regex(/^[a-zA-Z0-9._:-]{1,120}$/),
        zonaId: z.uuid(),
        nivel: z.int().min(1).max(3),
        emitidaEn: z.iso.datetime(),
      }),
    )
    .max(64),
});

/** Explicitly configured feed contract. No third-party API or official affiliation is guessed. */
@Injectable()
export class ConfiguredOfficialAlertSource implements OfficialAlertSource {
  private failures = 0;
  private retryAt = 0;
  constructor(
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}
  async read(): Promise<readonly OfficialAlert[]> {
    if (!this.config.EMERGENCY_ALERT_URL || this.clock.now().getTime() < this.retryAt) return [];
    try {
      const response = await fetch(this.config.EMERGENCY_ALERT_URL, {
        signal: AbortSignal.timeout(5000),
        redirect: 'error',
        headers: { Accept: 'application/json' },
      });
      if (!response.ok || !response.body) throw new Error('Fuente no disponible');
      const reader = response.body.getReader();
      const chunks: Uint8Array[] = [];
      let length = 0;
      try {
        while (true) {
          const chunk = await reader.read();
          if (chunk.done) break;
          length += chunk.value.byteLength;
          if (length > 262144) {
            await reader.cancel();
            throw new Error('Respuesta demasiado grande');
          }
          chunks.push(chunk.value);
        }
      } finally {
        reader.releaseLock();
      }
      const data = feedSchema.parse(JSON.parse(Buffer.concat(chunks).toString('utf8')));
      const now = this.clock.now().getTime();
      this.failures = 0;
      this.retryAt = 0;
      return data.alertas
        .filter((alert) => {
          const age = now - Date.parse(alert.emitidaEn);
          return age >= -300000 && age <= 86400000;
        })
        .map((alert) => ({
          externalId: alert.id,
          zoneId: alert.zonaId,
          level: alert.nivel,
          issuedAt: new Date(alert.emitidaEn),
        }));
    } catch {
      this.failures++;
      if (this.failures >= 3) this.retryAt = this.clock.now().getTime() + 120000;
      throw new Error('No se pudo consultar la fuente de alertas; se reintentará.');
    }
  }
}
