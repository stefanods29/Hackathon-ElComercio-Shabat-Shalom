import { Injectable } from '@nestjs/common';
import type { JobHandler, JobQueue } from './job-queue.js';

/** Compatible with Lot B: modules register first; the worker starts all handlers once. */
@Injectable()
export class JobHandlerRegistry {
  private readonly handlers = new Map<string, JobHandler<unknown>>();
  private started = false;

  register<T>(name: string, handler: JobHandler<T>): void {
    if (this.started || this.handlers.has(name))
      throw new Error('Registro de trabajo duplicado o tardío');
    this.handlers.set(name, handler as JobHandler<unknown>);
  }

  async startAll(queue: JobQueue): Promise<void> {
    if (this.started) throw new Error('Los manejadores ya se iniciaron');
    this.started = true;
    for (const [name, handler] of this.handlers) await queue.process(name, handler);
  }
}
