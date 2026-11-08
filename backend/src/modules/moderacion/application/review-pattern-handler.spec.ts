import type { TransactionContext, UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { newId } from '../../../shared/domain/ids.js';
import { JobHandlerRegistry } from '../../../shared/queues/job-handler.registry.js';
import { InMemoryJobQueue } from '../../../shared/queues/job-queue.memory.js';
import { ReviewPatternHandler } from './review-pattern-handler.js';

const NOW = new Date('2026-11-08T03:00:00Z');
const clock = { now: () => NOW };
const transaction = {} as TransactionContext;
const uow: UnitOfWork = { run: (work) => work(transaction) };

it('cuatro reseñas no abren caso y la quinta del dispositivo pasa a moderación', async () => {
  const reviewId = newId();
  const risk = {
    countDeviceReviewsForPendingReview: vi
      .fn(async () => 4)
      .mockResolvedValueOnce(4)
      .mockResolvedValueOnce(5),
  };
  const cases = { openReviewPatternCase: vi.fn(async () => {}) };
  const registry = new JobHandlerRegistry();
  const queue = new InMemoryJobQueue(clock);
  new ReviewPatternHandler(registry, uow, risk, cases, clock).onModuleInit();
  await registry.startAll(queue);
  await queue.enqueue('reputacion.resena_creada', { agregadoId: newId() });
  await queue.enqueue('reputacion.resena_creada', { agregadoId: reviewId });
  await queue.drain();
  expect(cases.openReviewPatternCase).toHaveBeenCalledTimes(1);
  expect(cases.openReviewPatternCase).toHaveBeenCalledWith(transaction, reviewId, NOW);
});
