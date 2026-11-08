import type { TransactionContext, UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { newId } from '../../../shared/domain/ids.js';
import { InMemoryOutboxWriter } from '../../../shared/outbox/outbox.memory.js';
import { JobHandlerRegistry } from '../../../shared/queues/job-handler.registry.js';
import { InMemoryJobQueue } from '../../../shared/queues/job-queue.memory.js';
import type { ServiceForReputation } from '../../directorio/index.js';
import { countsForRanking } from '../domain/endorsement.js';
import { InMemoryReputationRepository } from '../infrastructure/reputation.repository.memory.js';
import { InMemoryReviewPhotoReader } from '../infrastructure/review-photo.reader.memory.js';
import { Endorsements } from './endorsements.js';
import { RecalculateReputation } from './recalculate-reputation.js';
import { REPUTATION_RECALCULATION_JOB } from './reputation-events.js';
import { WriteReview } from './write-review.js';

const NOW = new Date('2026-11-08T03:00:00Z');
const BEFORE = new Date('2026-11-05T03:00:00Z');
const actor = { id: newId(), zoneId: newId(), trustLevel: 1 };
const owner = { ...actor, id: newId() };
const serviceId = newId();
const transaction = {} as TransactionContext;
const uow: UnitOfWork = { run: (work) => work(transaction) };
const command = () => ({
  id: newId(),
  serviceId,
  rating: 5,
  comment: null,
  fileIds: [] as string[],
});

function setup() {
  let now = NOW;
  const clock = { now: () => now };
  const repository = new InMemoryReputationRepository();
  const files = new InMemoryReviewPhotoReader();
  const outbox = new InMemoryOutboxWriter();
  const services = {
    findForReputation: vi.fn(async (): Promise<ServiceForReputation | null> => ({
      providerId: owner.id,
      zoneId: actor.zoneId,
      active: true,
    })),
  };
  const accounts = {
    findReviewer: vi.fn(async () => ({ createdAt: BEFORE, deviceHash: 'a'.repeat(64) })),
  };
  const reviews = new WriteReview(uow, repository, services, accounts, files, outbox, clock, {
    MIN_ACCOUNT_AGE_HOURS_TO_REVIEW: 72,
    MAX_REVIEWS_PER_DAY: 2,
  });
  const endorsements = new Endorsements(uow, repository, services, outbox, clock);
  const registry = new JobHandlerRegistry();
  const recalculate = new RecalculateReputation(registry, uow, repository, services, outbox, clock);
  recalculate.onModuleInit();
  return {
    repository,
    files,
    outbox,
    services,
    accounts,
    reviews,
    endorsements,
    registry,
    clock,
    advance: (milliseconds: number) => {
      now = new Date(now.getTime() + milliseconds);
    },
  };
}

describe('Escribir reseñas', () => {
  it('guarda en revisión y registra el evento con la transacción y el reloj de la reseña', async () => {
    const context = setup();
    const record = vi.spyOn(context.outbox, 'record');
    const result = await context.reviews.execute(command(), actor);
    expect(result).toMatchObject({
      created: true,
      review: { state: 'en_revision', createdAt: NOW, publishedAt: null },
    });
    expect(record).toHaveBeenCalledWith(transaction, 'reputacion', [
      expect.objectContaining({
        type: 'reputacion.resena_creada',
        aggregateId: result.review.id,
        occurredAt: NOW,
      }),
    ]);
  });

  it('un id propio es idempotente y distingue reseña duplicada de un id ajeno', async () => {
    const context = setup();
    const original = command();
    const first = await context.reviews.execute(original, actor);
    expect(await context.reviews.execute({ ...original, rating: 1 }, actor)).toEqual({
      review: first.review,
      created: false,
    });
    await expect(context.reviews.execute(command(), actor)).rejects.toMatchObject({
      code: 'resena_duplicada',
    });
    await expect(
      context.reviews.execute(original, { ...actor, id: newId() }),
    ).rejects.toMatchObject({ code: 'id_en_uso' });
    expect(context.repository.reviews.size).toBe(1);
    expect(context.outbox.recorded).toHaveLength(1);
  });

  it('exige nivel 1, zona propia y servicio vigente de otro proveedor', async () => {
    const context = setup();
    for (const [candidate, code] of [
      [{ ...actor, trustLevel: 0 }, 'nivel_de_confianza_insuficiente'],
      [{ ...actor, zoneId: null }, 'sin_zona'],
      [owner, 'no_puedes_resenarte'],
      [{ ...actor, zoneId: newId() }, 'fuera_de_tu_zona'],
    ] as const) {
      await expect(context.reviews.execute(command(), candidate)).rejects.toMatchObject({ code });
      await expect(context.endorsements.give(serviceId, candidate)).rejects.toMatchObject({ code });
    }
    context.services.findForReputation.mockResolvedValue({
      providerId: owner.id,
      zoneId: actor.zoneId,
      active: false,
    });
    await expect(context.reviews.execute(command(), actor)).rejects.toMatchObject({
      code: 'recurso_no_encontrado',
    });
    await expect(context.endorsements.give(serviceId, actor)).rejects.toMatchObject({
      code: 'recurso_no_encontrado',
    });
  });

  it('rechaza la cuenta nueva y admite exactamente el umbral de 72 horas', async () => {
    const context = setup();
    context.accounts.findReviewer.mockResolvedValueOnce({
      createdAt: new Date(BEFORE.getTime() + 1),
      deviceHash: 'a'.repeat(64),
    });
    await expect(context.reviews.execute(command(), actor)).rejects.toMatchObject({
      code: 'cuenta_muy_nueva',
    });
    await expect(context.reviews.execute(command(), actor)).resolves.toMatchObject({
      created: true,
    });
  });

  it('limita la ventana móvil, incluye las ocultas y el reintento del id no consume cuota', async () => {
    const context = setup();
    const first = command();
    const created = await context.reviews.execute(first, actor);
    context.repository.reviews.set(first.id, { ...created.review, state: 'oculta' });
    context.advance(1_000);
    await context.reviews.execute({ ...command(), serviceId: newId() }, actor);
    const third = { ...command(), serviceId: newId() };
    await expect(context.reviews.execute(third, actor)).rejects.toMatchObject({
      code: 'limite_diario_alcanzado',
      retryAfterSeconds: 86_399,
    });
    await expect(context.reviews.execute(first, actor)).resolves.toMatchObject({ created: false });
    context.advance(86_399_000);
    await expect(context.reviews.execute(third, actor)).resolves.toMatchObject({ created: true });
    expect(context.outbox.recorded).toHaveLength(3);
  });

  it('acepta fotos listas del autor en orden y rechaza las ajenas, pendientes o de otro propósito', async () => {
    const context = setup();
    const file = {
      id: newId(),
      ownerId: actor.id,
      width: 320,
      height: 200,
      blurhash: 'demo',
      purpose: 'resena',
      state: 'listo',
    } as const;
    const foreign = { ...file, id: newId(), ownerId: newId() };
    const pending = { ...file, id: newId(), state: 'pendiente' } as const;
    const otherPurpose = { ...file, id: newId(), purpose: 'servicio' } as const;
    const second = { ...file, id: newId() };
    for (const photo of [file, foreign, pending, otherPurpose, second])
      context.files.files.set(photo.id, photo);
    for (const id of [foreign.id, pending.id, otherPurpose.id, newId()]) {
      await expect(
        context.reviews.execute({ ...command(), fileIds: [id] }, actor),
      ).rejects.toMatchObject({ code: 'archivo_no_valido' });
    }
    expect(context.repository.reviews.size).toBe(0);
    expect(context.outbox.recorded).toHaveLength(0);
    const saved = await context.reviews.execute(
      { ...command(), fileIds: [second.id, file.id] },
      actor,
    );
    expect(
      saved.review.photos.map((photo) => ({ fileId: photo.fileId, order: photo.order })),
    ).toEqual([
      { fileId: second.id, order: 0 },
      { fileId: file.id, order: 1 },
    ]);
    expect(saved.review.state).toBe('en_revision');
  });
});

it('Visto Bueno conserva id y nivel inicial, y dos retiros solicitan un solo recálculo', async () => {
  const context = setup();
  const first = await context.endorsements.give(serviceId, actor);
  expect(countsForRanking(first)).toBe(false);
  expect(await context.endorsements.give(serviceId, { ...actor, trustLevel: 2 })).toEqual(first);
  expect(context.outbox.recorded).toHaveLength(1);
  await context.endorsements.withdraw(serviceId, actor);
  await context.endorsements.withdraw(serviceId, actor);
  expect(context.repository.endorsements.size).toBe(0);
  expect(context.outbox.recorded.map((event) => event.type)).toEqual([
    REPUTATION_RECALCULATION_JOB,
    REPUTATION_RECALCULATION_JOB,
  ]);
});

it('la cola vuelve a contar solo reseñas publicadas y vistos verificados de la zona en cada entrega', async () => {
  const context = setup();
  const approved = await context.reviews.execute(command(), actor);
  context.repository.reviews.set(approved.review.id, {
    ...approved.review,
    state: 'publicada',
    publishedAt: NOW,
  });
  await context.reviews.execute(command(), { ...actor, id: newId() });
  await context.endorsements.give(serviceId, actor);
  const verified = { ...actor, id: newId(), trustLevel: 2 };
  await context.endorsements.give(serviceId, verified);
  await context.repository.insertEndorsement(transaction, {
    serviceId,
    neighborId: newId(),
    neighborZoneId: newId(),
    trustLevelAtGiving: 3,
    createdAt: NOW,
  });
  const queue = new InMemoryJobQueue(context.clock);
  await context.registry.startAll(queue);
  const job = { agregadoId: serviceId, carga: { servicioId: serviceId } };
  await queue.enqueue(REPUTATION_RECALCULATION_JOB, job);
  await queue.enqueue(REPUTATION_RECALCULATION_JOB, job);
  await queue.drain();
  const summaries = () =>
    context.outbox.recorded
      .filter((event) => event.type === 'reputacion.agregados_recalculados')
      .map((event) => event.payload);
  const expected = {
    servicioId: serviceId,
    totalResenas: 1,
    sumaCalificaciones: 5,
    totalVistosBuenos: 3,
    vistosBuenosDeLaZona: 1,
  };
  expect(summaries()).toEqual([expected, expected]);
  await context.endorsements.withdraw(serviceId, verified);
  await queue.enqueue(REPUTATION_RECALCULATION_JOB, job);
  await queue.drain();
  expect(summaries().at(-1)).toEqual({
    ...expected,
    totalVistosBuenos: 2,
    vistosBuenosDeLaZona: 0,
  });
});
