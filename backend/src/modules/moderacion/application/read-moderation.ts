import { Inject, Injectable } from '@nestjs/common';
import { z } from 'zod';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { ValidationError } from '../../../shared/domain/errors.js';
import { CASE_STATES, type CaseCursor, type CaseState } from '../domain/moderation.js';
import { MODERATION_STORE, type ModerationStore } from './ports.js';

const cursorSchema = z.strictObject({
  createdAt: z.iso.datetime(),
  id: z.uuid(),
  state: z.enum(CASE_STATES),
});

function decode(value: string, state: CaseState): CaseCursor {
  try {
    const bytes = Buffer.from(value, 'base64url');
    if (bytes.toString('base64url') !== value) throw new Error('Codificación inválida.');
    const cursor = cursorSchema.parse(JSON.parse(bytes.toString('utf8')));
    if (cursor.state !== state) throw new Error('Estado inválido.');
    return cursor;
  } catch {
    throw new ValidationError([
      { field: 'cursor', message: 'Usa el cursor de la página anterior para este estado.' },
    ]);
  }
}

@Injectable()
export class ReadModeration {
  constructor(
    @Inject(MODERATION_STORE) private readonly store: ModerationStore,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  async queue(state: CaseState, limit: number, value?: string) {
    const rows = await this.store.list(state, limit + 1, value ? decode(value, state) : undefined);
    const cases = rows.slice(0, limit);
    const last = rows.length > limit ? cases.at(-1) : undefined;
    const next = last
      ? Buffer.from(JSON.stringify({ createdAt: last.cursorDate, id: last.id, state })).toString(
          'base64url',
        )
      : null;
    return { cases, next };
  }

  async metrics(from?: string, until?: string) {
    const end = until ? new Date(until) : this.clock.now();
    const start = from ? new Date(from) : new Date(end.getTime() - 7 * 86_400_000);
    if (start >= end) {
      throw new ValidationError([{ field: 'desde', message: 'Debe ser anterior a hasta.' }]);
    }
    const metrics = await this.store.metrics(start, end);
    return {
      desde: start.toISOString(),
      hasta: end.toISOString(),
      totalCasos: metrics.total,
      pendientes: metrics.pending,
      p90PrimeraRevisionSegundos: metrics.p90Seconds,
    };
  }
}
