import type { TransactionContext, UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { newId } from '../../../shared/domain/ids.js';
import { JobHandlerRegistry } from '../../../shared/queues/job-handler.registry.js';
import { InMemoryJobQueue } from '../../../shared/queues/job-queue.memory.js';
import { ReputationAggregatesHandler } from './reputation-aggregates-handler.js';

const NOW = new Date('2026-11-08T03:00:00Z');
const clock = { now: () => NOW };
const transaction = {} as TransactionContext;
const uow: UnitOfWork = { run: (work) => work(transaction) };
const id = newId();
const otherId = newId();
const event = {
  eventoId: newId(),
  agregadoId: id,
  ocurridoEn: NOW.toISOString(),
  carga: {
    servicioId: id,
    totalResenas: 2,
    sumaCalificaciones: 9,
    totalVistosBuenos: 2,
    vistosBuenosDeLaZona: 1,
  },
};

it('el manejador usa la media ponderada de toda la categoría y omite el evento ya aplicado', async () => {
  const store = {
    applyFacts: vi
      .fn(async (): Promise<string | null> => 'gasfiteria')
      .mockResolvedValueOnce('gasfiteria')
      .mockResolvedValueOnce(null),
    categoryFacts: vi.fn(async () => [
      { id, reviewCount: 2, ratingSum: 9 },
      { id: otherId, reviewCount: 3, ratingSum: 11 },
    ]),
    saveScores: vi.fn(async () => {}),
  };
  const registry = new JobHandlerRegistry();
  const queue = new InMemoryJobQueue(clock);
  new ReputationAggregatesHandler(registry, uow, store, clock).onModuleInit();
  await registry.startAll(queue);
  await queue.enqueue('reputacion.agregados_recalculados', event);
  await queue.enqueue('reputacion.agregados_recalculados', event);
  await queue.drain();
  expect(store.applyFacts).toHaveBeenCalledWith(
    transaction,
    event.carga,
    { eventId: event.eventoId, occurredAt: event.ocurridoEn },
    NOW,
  );
  expect(store.categoryFacts).toHaveBeenCalledTimes(1);
  expect(store.saveScores).toHaveBeenCalledTimes(1);
  expect(store.saveScores).toHaveBeenCalledWith(
    transaction,
    'gasfiteria',
    [
      { id, score: 37 / 9 },
      { id: otherId, score: 39 / 10 },
    ],
    NOW,
  );
});

it('el manejador rechaza totales incompatibles antes de escribir', async () => {
  const store = {
    applyFacts: vi.fn(async () => null),
    categoryFacts: vi.fn(async () => []),
    saveScores: vi.fn(async () => {}),
  };
  const handler = new ReputationAggregatesHandler(new JobHandlerRegistry(), uow, store, clock);
  await expect(
    handler.handle({ ...event, carga: { ...event.carga, sumaCalificaciones: 11 } }),
  ).rejects.toThrow();
  await expect(
    handler.handle({ ...event, carga: { ...event.carga, vistosBuenosDeLaZona: 3 } }),
  ).rejects.toThrow();
  expect(store.applyFacts).not.toHaveBeenCalled();
});
