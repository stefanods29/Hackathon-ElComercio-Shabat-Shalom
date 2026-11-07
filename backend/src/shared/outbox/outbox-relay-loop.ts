import { Logger } from '@nestjs/common';
import type { OutboxRelay } from './outbox-relay.js';

/** One in-flight batch per process, even when a batch takes longer than the interval. */
export class OutboxRelayLoop {
  private readonly logger = new Logger(OutboxRelayLoop.name);
  private timer?: ReturnType<typeof setInterval>;
  private running?: Promise<void>;
  private stopped = true;

  constructor(private readonly relay: Pick<OutboxRelay, 'runOnce'>) {}

  start(): void {
    if (!this.stopped) throw new Error('El relay ya está iniciado.');
    this.stopped = false;
    this.tick();
    this.timer = setInterval(() => this.tick(), 1000);
    this.timer.unref();
  }

  async stop(): Promise<void> {
    this.stopped = true;
    clearInterval(this.timer);
    await this.running;
  }

  private tick(): void {
    if (this.stopped || this.running) return;
    this.running = this.relay
      .runOnce()
      .then(() => undefined)
      .catch(() => {
        this.logger.error('El relay falló; se reintentará en la siguiente vuelta.');
      })
      .finally(() => {
        this.running = undefined;
      });
  }
}
