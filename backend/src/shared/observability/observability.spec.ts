import { EventEmitter } from 'node:events';
import type { NextFunction, Response } from 'express';
import { isUuidV7 } from '../domain/ids.js';
import { InMemoryJobQueue } from '../queues/job-queue.memory.js';
import { IdempotencyCounters } from './idempotency-counters.js';
import {
  HttpRequestLogger,
  RequestIdMiddleware,
  type CorrelatedRequest,
  problemInstance,
  requestIdFor,
} from './request-id.middleware.js';

describe('Correlación y logs', () => {
  it('respeta ids válidos y reemplaza cabeceras inválidas sin reflejarlas', () => {
    expect(requestIdFor('cliente:prueba-1')).toBe('cliente:prueba-1');
    for (const value of [
      undefined,
      ['dos', 'ids'],
      '',
      'a'.repeat(129),
      'con espacios',
      'línea\nnueva',
    ])
      expect(isUuidV7(requestIdFor(value))).toBe(true);
    expect(
      problemInstance({ originalUrl: '/v1/publicaciones?lat=privado&token=secreto' }, 'abc'),
    ).toBe('/v1/publicaciones#requestId=abc');
  });

  it.each([false, true])('registra una sola vez y omite datos sensibles (aborto=%s)', (aborted) => {
    const logger = new HttpRequestLogger();
    const record = vi.spyOn(logger, 'record').mockImplementation(() => {});
    const middleware = new RequestIdMiddleware(logger);
    const request = {
      headers: { 'x-request-id': 'traza-1', authorization: 'secreto' },
      method: 'GET',
      originalUrl: '/secreto?lat=privado',
      route: { path: '/v1/publicaciones' },
      body: { refreshToken: 'secreto' },
    } as unknown as CorrelatedRequest;
    const response = Object.assign(new EventEmitter(), {
      setHeader: vi.fn(),
      statusCode: 200,
      writableFinished: !aborted,
    });
    const next = vi.fn();
    middleware.use(request, response as unknown as Response, next as NextFunction);
    expect(request.requestId).toBe('traza-1');
    expect(response.setHeader).toHaveBeenCalledWith('x-request-id', 'traza-1');
    expect(next).toHaveBeenCalledOnce();
    response.emit(aborted ? 'close' : 'finish');
    response.emit('close');
    expect(record).toHaveBeenCalledOnce();
    expect(record).toHaveBeenCalledWith(
      expect.objectContaining({
        requestId: 'traza-1',
        ruta: '/v1/publicaciones',
        estado: aborted ? 499 : 200,
        duracionMs: expect.any(Number),
      }),
    );
    expect(JSON.stringify(record.mock.calls)).not.toMatch(/secreto|privado/);
  });
});

describe('Contadores de proceso', () => {
  it('distingue los cuatro resultados y entrega una copia sin secretos', () => {
    const counters = new IdempotencyCounters({ now: () => new Date('2026-11-07T15:00:00Z') });
    counters.record('new');
    counters.record('replay');
    counters.record('replay');
    counters.record('in_progress');
    counters.record('fingerprint_mismatch');
    expect(counters.snapshot()).toEqual({ nueva: 1, repetida: 2, enCurso: 1, huellaDistinta: 1 });
    counters.snapshot().nueva = 100;
    expect(counters.snapshot().nueva).toBe(1);
    expect(counters.startedAt.toISOString()).toBe('2026-11-07T15:00:00.000Z');
  });
});

describe('Métricas de la cola de pruebas', () => {
  it('diferencia cola diferida, crítica lista, activa y fallida', async () => {
    const now = new Date('2026-11-07T15:00:00Z');
    const queue = new InMemoryJobQueue({ now: () => now });
    await queue.enqueue('prueba', { secreto: 'no sale' }, { priority: 'critical' });
    await queue.enqueue('prueba', {}, { priority: 'critical', delaySeconds: 600 });
    expect(await queue.depths(new Date(now.getTime() + 10_000))).toEqual([
      {
        name: 'prueba',
        pending: 2,
        active: 0,
        failed: 0,
        criticalPending: 2,
        oldestCriticalAgeSeconds: 10,
      },
    ]);
    await queue.process('prueba', async () => {
      expect((await queue.depths(now))[0]?.active).toBe(1);
      throw new Error('fallo');
    });
    await expect(queue.drain()).rejects.toThrow('fallo');
    expect((await queue.depths(now))[0]).toMatchObject({
      pending: 1,
      active: 0,
      failed: 1,
      oldestCriticalAgeSeconds: null,
    });
  });
});
