import { Inject, Injectable } from '@nestjs/common';
import { CLOCK, type Clock } from '../domain/clock.js';
import { newId } from '../domain/ids.js';
import type { ReservationResult } from '../idempotency/idempotency-store.js';

@Injectable()
export class IdempotencyCounters {
  readonly instanceId = newId();
  readonly startedAt: Date;
  private readonly counts = { new: 0, replay: 0, in_progress: 0, fingerprint_mismatch: 0 };

  constructor(@Inject(CLOCK) clock: Clock) {
    this.startedAt = clock.now();
  }

  record(kind: ReservationResult['kind']): void {
    this.counts[kind] += 1;
  }

  snapshot(): { nueva: number; repetida: number; enCurso: number; huellaDistinta: number } {
    return {
      nueva: this.counts.new,
      repetida: this.counts.replay,
      enCurso: this.counts.in_progress,
      huellaDistinta: this.counts.fingerprint_mismatch,
    };
  }
}
