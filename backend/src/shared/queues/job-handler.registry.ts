import { Injectable } from '@nestjs/common';
import type { JobHandler, JobQueue } from './job-queue.js';

/** Business modules register handlers in onModuleInit, before workers start consuming. */
@Injectable()
export class JobHandlerRegistry {
  private readonly handlers = new Map<string, JobHandler<unknown>>();
  private started = false;

  register<T>(name: string, handler: JobHandler<T>): void {
    if (this.started)
      throw new Error('Los manejadores deben registrarse antes de iniciar los workers.');
    if (this.handlers.has(name)) throw new Error('Manejador duplicado: ' + name);
    this.handlers.set(name, handler as JobHandler<unknown>);
  }

  async startAll(queue: JobQueue): Promise<void> {
    if (this.started) throw new Error('Los workers ya están iniciados.');
    this.started = true;
    for (const [name, handler] of this.handlers) await queue.process(name, handler);
  }
}
