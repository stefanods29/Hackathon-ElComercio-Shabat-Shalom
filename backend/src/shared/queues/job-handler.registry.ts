import { Injectable } from '@nestjs/common';
import type { JobHandler, JobQueue } from './job-queue.js';

/** Business modules register handlers in onModuleInit, before workers start consuming. */
@Injectable()
export class JobHandlerRegistry {
  private readonly handlers = new Map<string, (data: unknown) => Promise<void | boolean>>();
  private readonly subscribers = new Map<string, Map<string, JobHandler<unknown>>>();
  private started = false;

  /** A primary handler can return false to skip subscribers for an obsolete event. */
  register<T>(name: string, handler: (data: T) => Promise<void | boolean>): void {
    if (this.started)
      throw new Error('Los manejadores deben registrarse antes de iniciar los workers.');
    if (this.handlers.has(name)) throw new Error('Manejador duplicado: ' + name);
    this.handlers.set(name, handler as (data: unknown) => Promise<void | boolean>);
  }

  /** A second owner may observe a durable event without replacing its primary handler. */
  subscribe<T>(name: string, subscriber: string, handler: JobHandler<T>): void {
    if (this.started)
      throw new Error('Los suscriptores deben registrarse antes de iniciar los workers.');
    const group = this.subscribers.get(name) ?? new Map<string, JobHandler<unknown>>();
    if (group.has(subscriber)) throw new Error('Suscriptor duplicado: ' + subscriber);
    group.set(subscriber, handler as JobHandler<unknown>);
    this.subscribers.set(name, group);
  }

  async startAll(queue: JobQueue): Promise<void> {
    if (this.started) throw new Error('Los workers ya están iniciados.');
    this.started = true;
    const names = new Set([...this.handlers.keys(), ...this.subscribers.keys()]);
    for (const name of names) {
      const primary = this.handlers.get(name);
      const subscribers = this.subscribers.get(name);
      await queue.process(name, async (data) => {
        if ((await primary?.(data)) === false) return;
        // Every subscriber must be retry-safe: failure retries delivery of the whole event.
        for (const handle of subscribers?.values() ?? []) await handle(data);
      });
    }
  }
}
