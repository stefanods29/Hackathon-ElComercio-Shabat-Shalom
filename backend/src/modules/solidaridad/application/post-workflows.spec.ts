import { testConfig } from '../../../../test/support/config.js';
import type { TransactionContext, UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { newId } from '../../../shared/domain/ids.js';
import { InMemoryOutboxWriter } from '../../../shared/outbox/outbox.memory.js';
import { InMemoryPostRepository } from '../infrastructure/post.repository.memory.js';
import { CancelPost } from './cancel-post.js';
import { ResolveFavor } from './resolve-favor.js';
import { PublishPost } from './publish-post.js';
import { TakeFavor } from './take-favor.js';
import { FindNearbyPosts } from './find-nearby-posts.js';
import { decodeNearbyCursor, encodeNearbyCursor } from './nearby-cursor.js';

const config = testConfig({ MAX_POSTS_PER_DAY: '2' });
const author = { id: newId(), zoneId: newId(), trustLevel: 1 };
const taker = { ...author, id: newId() };
const command = () => ({
  id: newId(),
  type: 'presto' as const,
  category: 'agua',
  title: 'Presto bidones de agua',
});
const unitOfWork: UnitOfWork = { run: (work) => work({} as TransactionContext) };

function setup() {
  let now = new Date('2026-11-07T15:00:00Z');
  const clock = { now: () => now };
  const posts = new InMemoryPostRepository();
  const outbox = new InMemoryOutboxWriter();
  return {
    posts,
    outbox,
    advance: (milliseconds: number) => {
      now = new Date(now.getTime() + milliseconds);
    },
    publish: new PublishPost(unitOfWork, posts, outbox, clock, config),
    take: new TakeFavor(unitOfWork, posts, outbox, clock),
    cancel: new CancelPost(unitOfWork, posts, outbox, clock),
    resolve: new ResolveFavor(unitOfWork, posts, outbox, clock),
  };
}

describe('Transiciones de publicación', () => {
  it.each(['cancel', 'resolve'] as const)(
    '%s registra un evento y no lo duplica al repetir',
    async (action) => {
      const context = setup();
      const { post } = await context.publish.execute(command(), author);
      if (action === 'resolve')
        await context.take.execute({ postId: post.id, seenVersion: 1 }, taker);
      const before = action === 'resolve' ? 2 : 1;
      const first = await context[action].execute({ postId: post.id, seenVersion: before }, author);
      const retry = await context[action].execute({ postId: post.id, seenVersion: before }, author);
      expect(retry).toEqual(first);
      expect(first.version).toBe(before + 1);
      expect(
        context.outbox.recorded.filter(
          (event) =>
            event.type ===
            (action === 'cancel'
              ? 'solidaridad.publicacion_cancelada'
              : 'solidaridad.favor_resuelto'),
        ),
      ).toHaveLength(1);
    },
  );

  it.each(['cancel', 'resolve'] as const)(
    '%s explica la carrera y no publica el evento perdedor',
    async (action) => {
      const context = setup();
      const { post } = await context.publish.execute(command(), author);
      if (action === 'resolve')
        await context.take.execute({ postId: post.id, seenVersion: 1 }, taker);
      vi.spyOn(context.posts, 'updateIfVersion').mockImplementationOnce(async () => {
        context.posts.force({
          ...post,
          status: action === 'cancel' ? 'en_curso' : 'cancelada',
          version: 3,
          takenById: action === 'cancel' ? taker.id : null,
        });
        return false;
      });
      const count = context.outbox.recorded.length;
      await expect(
        context[action].execute(
          { postId: post.id, seenVersion: action === 'resolve' ? 2 : 1 },
          author,
        ),
      ).rejects.toMatchObject({
        code: action === 'cancel' ? 'no_se_puede_cancelar' : 'favor_no_en_curso',
      });
      expect(context.outbox.recorded).toHaveLength(count);
    },
  );

  it.each(['cancel', 'resolve'] as const)(
    '%s reconoce la misma transición ganadora y no duplica su evento',
    async (action) => {
      const context = setup();
      const { post } = await context.publish.execute(command(), author);
      if (action === 'resolve')
        await context.take.execute({ postId: post.id, seenVersion: 1 }, taker);
      vi.spyOn(context.posts, 'updateIfVersion').mockImplementationOnce(async () => {
        context.posts.force({
          ...post,
          status: action === 'cancel' ? 'cancelada' : 'resuelta',
          version: 3,
          takenById: action === 'resolve' ? taker.id : null,
        });
        return false;
      });
      const count = context.outbox.recorded.length;
      await expect(
        context[action].execute(
          { postId: post.id, seenVersion: action === 'resolve' ? 2 : 1 },
          author,
        ),
      ).resolves.toMatchObject({ version: 3 });
      expect(context.outbox.recorded).toHaveLength(count);
    },
  );

  it.each(['cancel', 'resolve'] as const)(
    '%s rechaza una zona ajena o un id inexistente',
    async (action) => {
      const context = setup();
      const { post } = await context.publish.execute(command(), author);
      await expect(
        context[action].execute(
          { postId: post.id, seenVersion: 1 },
          { ...author, zoneId: newId() },
        ),
      ).rejects.toMatchObject({ code: 'fuera_de_tu_zona' });
      await expect(
        context[action].execute({ postId: newId(), seenVersion: 1 }, author),
      ).rejects.toMatchObject({ code: 'recurso_no_encontrado' });
    },
  );
});

describe('Límite móvil de publicaciones', () => {
  it('rechaza al alcanzar el máximo, incluye canceladas y calcula la espera desde la más antigua', async () => {
    const context = setup();
    const first = await context.publish.execute(command(), author);
    await context.cancel.execute({ postId: first.post.id, seenVersion: 1 }, author);
    context.advance(60_000);
    await context.publish.execute(command(), author);
    await expect(context.publish.execute(command(), author)).rejects.toMatchObject({
      code: 'limite_diario_alcanzado',
      retryAfterSeconds: 86_340,
    });
    expect(
      context.outbox.recorded.filter((event) => event.type === 'solidaridad.publicacion_creada'),
    ).toHaveLength(2);
  });

  it('el reintento del id no consume plaza aunque el vencimiento de su cuerpo ya haya pasado', async () => {
    const context = setup();
    const body = { ...command(), expiresAt: new Date('2026-11-07T15:01:00Z') };
    await context.publish.execute(body, author);
    await context.publish.execute(command(), author);
    context.advance(120_000);
    await expect(context.publish.execute(body, author)).resolves.toMatchObject({ created: false });
    expect(context.outbox.recorded).toHaveLength(2);
  });

  it('libera plaza exactamente al cumplir 24 horas sin afectar a otro autor', async () => {
    const context = setup();
    await context.publish.execute(command(), author);
    context.advance(60_000);
    await context.publish.execute(command(), author);
    await context.publish.execute(command(), taker);
    context.advance(86_340_000);
    await expect(context.publish.execute(command(), author)).resolves.toMatchObject({
      created: true,
    });
  });
});

describe('Cursor y ámbito de la búsqueda', () => {
  it('rechaza un cursor malformado antes de consultar y exige zona', async () => {
    const reader = { findNearby: vi.fn(async () => ({ data: [], nextCursor: null })) };
    const search = new FindNearbyPosts(reader, { now: () => new Date('2026-11-07T15:00:00Z') });
    const query = { location: { lat: -12, lng: -77 }, radius: 2000, limit: 20 };
    await expect(search.execute({ ...query, cursor: '!' }, author)).rejects.toMatchObject({
      code: 'validacion',
    });
    await expect(search.execute(query, { ...author, zoneId: null })).rejects.toMatchObject({
      code: 'sin_zona',
    });
    expect(reader.findNearby).not.toHaveBeenCalled();
    await expect(search.execute(query, author)).resolves.toEqual({ data: [], nextCursor: null });
    expect(reader.findNearby).toHaveBeenCalledWith(
      expect.objectContaining({ zoneId: author.zoneId }),
    );
  });

  it.each([
    null,
    [],
    { d: -50, id: newId() },
    { d: 42, id: newId() },
    { d: 5050, id: newId() },
    { d: 50, id: 'desconocido' },
    { d: 50, id: newId(), lat: -12 },
  ])('rechaza un cursor con contenido inválido: %j', (data) => {
    const value = Buffer.from(JSON.stringify(data)).toString('base64url');
    expect(() => decodeNearbyCursor(value)).toThrow(
      expect.objectContaining({ code: 'validacion' }),
    );
  });

  it('transporta únicamente el id y la misma distancia redondeada de la respuesta', () => {
    const cursor = { d: 550, id: newId() };
    expect(decodeNearbyCursor(encodeNearbyCursor(cursor))).toEqual(cursor);
  });
});
