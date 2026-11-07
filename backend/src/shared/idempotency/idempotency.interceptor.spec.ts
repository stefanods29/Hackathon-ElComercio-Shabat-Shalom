import { Body, Controller, HttpCode, type INestApplication, Post } from '@nestjs/common';
import { APP_FILTER, APP_INTERCEPTOR, APP_PIPE } from '@nestjs/core';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { z } from 'zod';
import { ProblemDetailsFilter } from '../api/problem-details.filter.js';
import { createValidationPipe } from '../api/validation.js';
import { CLOCK, type Clock } from '../domain/clock.js';
import { BusinessRuleViolation } from '../domain/errors.js';
import { IDEMPOTENCY_STORE } from './idempotency-store.js';
import { InMemoryIdempotencyStore } from './idempotency-store.memory.js';
import { IdempotencyInterceptor } from './idempotency.interceptor.js';
import { Idempotent } from './idempotent.decorator.js';
import { IdempotencyCounters } from '../observability/idempotency-counters.js';

let executions = 0;
let failWith: 'none' | 'transient' | 'definitive' = 'none';

const schema = z.object({ texto: z.string().min(1) });

@Controller('prueba')
class TestController {
  @Post()
  @Idempotent()
  @HttpCode(201)
  create(@Body({ schema }) body: z.infer<typeof schema>): { numero: number; texto: string } {
    executions += 1;
    if (failWith === 'transient') throw new Error('se cayó la base');
    if (failWith === 'definitive') {
      throw new BusinessRuleViolation('favor_no_disponible', 'Ya lo tomó otro vecino.', 'conflict');
    }
    return { numero: executions, texto: body.texto };
  }

  @Post('libre')
  free(): { ok: true } {
    return { ok: true };
  }
}

describe('IdempotencyInterceptor', () => {
  let app: INestApplication;
  const clock: Clock = { now: () => new Date('2026-11-06T15:00:00Z') };
  const KEY = '019a5c3e-7d2b-7c11-9a00-000000000001';

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      controllers: [TestController],
      providers: [
        { provide: CLOCK, useValue: clock },
        IdempotencyCounters,
        { provide: IDEMPOTENCY_STORE, useValue: new InMemoryIdempotencyStore() },
        { provide: APP_INTERCEPTOR, useClass: IdempotencyInterceptor },
        { provide: APP_FILTER, useClass: ProblemDetailsFilter },
        { provide: APP_PIPE, useFactory: createValidationPipe },
      ],
    }).compile();
    app = moduleRef.createNestApplication({ logger: false });
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  beforeEach(() => {
    executions = 0;
    failWith = 'none';
  });

  const send = (key: string | null, body: object = { texto: 'hola' }) => {
    const pending = request(app.getHttpServer()).post('/prueba').send(body);
    return key ? pending.set('Idempotency-Key', key) : pending;
  };

  it('ejecuta una sola vez y repite la respuesta guardada con 200', async () => {
    const first = await send(`${KEY}a`).expect(201);
    const second = await send(`${KEY}a`).expect(200);
    expect(second.body).toEqual(first.body);
    expect(second.headers['idempotent-replayed']).toBe('true');
    expect(executions).toBe(1);
  });

  it('exige la cabecera en las escrituras marcadas', async () => {
    const response = await send(null).expect(400);
    expect(response.headers['content-type']).toContain('application/problem+json');
    expect(response.body).toMatchObject({
      codigo: 'validacion',
      errores: [{ campo: 'Idempotency-Key' }],
    });
    await request(app.getHttpServer()).post('/prueba/libre').expect(201);
  });

  it('rechaza la misma clave con otro contenido (422)', async () => {
    await send(`${KEY}b`, { texto: 'uno' }).expect(201);
    const response = await send(`${KEY}b`, { texto: 'otro' }).expect(422);
    expect(response.body.codigo).toBe('idempotency_key_reutilizada');
  });

  it('un error transitorio libera la clave: el reintento vuelve a ejecutarse', async () => {
    failWith = 'transient';
    await send(`${KEY}c`).expect(500);
    failWith = 'none';
    await send(`${KEY}c`).expect(201);
    expect(executions).toBe(2);
  });

  it('un rechazo definitivo se guarda y se repite igual sin volver a ejecutar', async () => {
    failWith = 'definitive';
    const first = await send(`${KEY}d`).expect(409);
    failWith = 'none';
    const second = await send(`${KEY}d`).expect(409);
    const { instance: _firstInstance, requestId: _firstRequestId, ...firstRejection } = first.body;
    const {
      instance: _secondInstance,
      requestId: _secondRequestId,
      ...secondRejection
    } = second.body;
    expect(secondRejection).toEqual(firstRejection);
    expect(second.body.requestId).not.toBe(first.body.requestId);
    expect(second.body.codigo).toBe('favor_no_disponible');
    expect(executions).toBe(1);
  });

  it('un cuerpo inválido es un rechazo definitivo: la acción corregida necesita otra clave', async () => {
    await send(`${KEY}e`, { texto: '' }).expect(400);
    await send(`${KEY}e`, { texto: '' }).expect(400);
    await send(`${KEY}e`, { texto: 'corregido' }).expect(422);
    await send(`${KEY}f`, { texto: 'corregido' }).expect(201);
    expect(executions).toBe(1);
  });
});
