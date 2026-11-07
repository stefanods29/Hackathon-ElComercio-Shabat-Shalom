import type { TransactionContext, UnitOfWork } from '../../../shared/db/unit-of-work.js';
import type { Clock } from '../../../shared/domain/clock.js';
import { BusinessRuleViolation, VersionConflict } from '../../../shared/domain/errors.js';
import { newId } from '../../../shared/domain/ids.js';
import { InMemoryOutboxWriter } from '../../../shared/outbox/outbox.memory.js';
import { InMemoryPostRepository } from '../infrastructure/post.repository.memory.js';
import type { NeighborActor } from './ports.js';
import { PublishPost } from './publish-post.js';
import { TakeFavor } from './take-favor.js';

const ZONE = '01970000-0000-7000-8000-000000000001';
const OTHER_ZONE = '01970000-0000-7000-8000-000000000002';
const ana: NeighborActor = {
  id: '01970000-0000-7000-8000-0000000000a1',
  zoneId: ZONE,
  trustLevel: 2,
};
const beto: NeighborActor = {
  id: '01970000-0000-7000-8000-0000000000b1',
  zoneId: ZONE,
  trustLevel: 1,
};
const carla: NeighborActor = {
  id: '01970000-0000-7000-8000-0000000000c1',
  zoneId: ZONE,
  trustLevel: 3,
};

const unitOfWork: UnitOfWork = {
  run: (work) => work({} as TransactionContext),
};
const clock: Clock = { now: () => new Date('2026-11-06T15:00:00Z') };

function setup() {
  const posts = new InMemoryPostRepository();
  const outbox = new InMemoryOutboxWriter();
  return {
    posts,
    outbox,
    publish: new PublishPost(unitOfWork, posts, outbox, clock),
    take: new TakeFavor(unitOfWork, posts, outbox, clock),
  };
}

async function codeOf(pending: Promise<unknown>): Promise<string | undefined> {
  try {
    await pending;
  } catch (error) {
    if (error instanceof BusinessRuleViolation || error instanceof VersionConflict) {
      return error.code;
    }
    throw error;
  }
  return undefined;
}

const command = (id = newId()) => ({
  id,
  type: 'necesito' as const,
  category: 'agua',
  title: 'Necesito bidones de agua',
});

describe('PublishPost', () => {
  it('crea la publicación y deja el evento en el outbox', async () => {
    const { publish, outbox } = setup();
    const result = await publish.execute(command(), ana);
    expect(result.created).toBe(true);
    expect(result.post.authorId).toBe(ana.id);
    expect(outbox.recorded.map((event) => event.type)).toEqual(['solidaridad.publicacion_creada']);
  });

  it('un reintento con el mismo id no duplica nada', async () => {
    const { publish, outbox } = setup();
    const id = newId();
    await publish.execute(command(id), ana);
    const retry = await publish.execute(command(id), ana);
    expect(retry.created).toBe(false);
    expect(outbox.recorded).toHaveLength(1);
  });

  it('no deja reutilizar el id de otra persona', async () => {
    const { publish } = setup();
    const id = newId();
    await publish.execute(command(id), ana);
    expect(await codeOf(publish.execute(command(id), beto))).toBe('id_en_uso');
  });

  it('exige nivel de confianza 1 y una zona', async () => {
    const { publish } = setup();
    expect(await codeOf(publish.execute(command(), { ...ana, trustLevel: 0 }))).toBe(
      'nivel_de_confianza_insuficiente',
    );
    expect(await codeOf(publish.execute(command(), { ...ana, zoneId: null }))).toBe('sin_zona');
  });
});

describe('TakeFavor', () => {
  it('dos vecinos lo toman sin conexión: el primero gana y el segundo recibe el motivo', async () => {
    const { publish, take, outbox } = setup();
    const { post } = await publish.execute(command(), ana);

    const first = await take.execute({ postId: post.id, seenVersion: 1 }, beto);
    expect(first.status).toBe('en_curso');
    expect(first.version).toBe(2);
    expect(await codeOf(take.execute({ postId: post.id, seenVersion: 1 }, carla))).toBe(
      'favor_no_disponible',
    );
    expect(outbox.recorded.map((event) => event.type)).toEqual([
      'solidaridad.publicacion_creada',
      'solidaridad.favor_tomado',
    ]);
  });

  it('si otro vecino gana la carrera entre la lectura y la escritura, explica el motivo', async () => {
    const { publish, take, posts } = setup();
    const { post } = await publish.execute(command(), ana);
    const original = posts.updateIfVersion.bind(posts);
    posts.updateIfVersion = async (transaction, changed, previousVersion) => {
      posts.force({ ...post, status: 'en_curso', takenById: carla.id, version: 2 });
      return original(transaction, changed, previousVersion);
    };
    expect(await codeOf(take.execute({ postId: post.id, seenVersion: 1 }, beto))).toBe(
      'favor_no_disponible',
    );
  });

  it('solo se toman favores de la propia zona', async () => {
    const { publish, take } = setup();
    const { post } = await publish.execute(command(), ana);
    expect(
      await codeOf(
        take.execute({ postId: post.id, seenVersion: 1 }, { ...beto, zoneId: OTHER_ZONE }),
      ),
    ).toBe('fuera_de_tu_zona');
  });
});
