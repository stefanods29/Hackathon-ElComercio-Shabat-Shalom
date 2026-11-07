import { newId } from '../../../shared/domain/ids.js';
import {
  FAVOR_RESOLVED_EVENT,
  POST_CANCELLED_EVENT,
  POST_STATUSES,
  Post,
  type PostStatus,
} from './post.js';

const AUTHOR = newId();
const TAKER = newId();
const OTHER = newId();
const NOW = new Date('2026-11-07T15:00:00Z');

function restore(status: PostStatus): Post {
  const post = Post.create(
    {
      id: newId(),
      authorId: AUTHOR,
      zoneId: newId(),
      type: 'presto',
      category: 'agua',
      title: 'Presto bidones',
    },
    new Date('2026-11-06T15:00:00Z'),
  );
  return Post.restore({
    ...post.snapshot(),
    status,
    version: 7,
    takenById: ['en_curso', 'resuelta'].includes(status) ? TAKER : null,
  });
}

describe('Ciclo de vida del favor', () => {
  for (const status of POST_STATUSES) {
    for (const [name, actor] of [
      ['autor', AUTHOR],
      ['tomador', TAKER],
      ['tercero', OTHER],
    ] as const) {
      it(`cancelar ${status} como ${name}: autorización, estado y evento`, () => {
        const post = restore(status);
        const before = post.snapshot();
        if (actor !== AUTHOR) {
          expect(() => post.cancel(actor, 7, NOW)).toThrow(
            expect.objectContaining({ code: 'no_eres_el_autor', kind: 'forbidden' }),
          );
          expect(post.snapshot()).toEqual(before);
        } else if (status === 'abierta') {
          expect(post.cancel(actor, 7, NOW)).toBe('cancelled');
          expect(post.snapshot()).toMatchObject({
            status: 'cancelada',
            version: 8,
            updatedAt: NOW,
          });
          expect(post.pullEvents()).toEqual([
            expect.objectContaining({
              type: POST_CANCELLED_EVENT,
              aggregateId: post.id,
              occurredAt: NOW,
              payload: { autorId: AUTHOR, zonaId: before.zoneId },
            }),
          ]);
          expect(post.cancel(actor, 7, NOW)).toBe('already_cancelled');
          expect(post.version).toBe(8);
        } else if (status === 'cancelada') {
          expect(post.cancel(actor, 1, NOW)).toBe('already_cancelled');
          expect(post.snapshot()).toEqual(before);
        } else {
          expect(() => post.cancel(actor, 7, NOW)).toThrow(
            expect.objectContaining({
              code: 'no_se_puede_cancelar',
              kind: 'conflict',
              extensions: { estadoActual: status },
            }),
          );
          expect(post.snapshot()).toEqual(before);
        }
        expect(post.pullEvents()).toEqual([]);
      });

      it(`resolver ${status} como ${name}: autorización, estado y evento`, () => {
        const post = restore(status);
        const before = post.snapshot();
        if (actor !== AUTHOR && before.takenById !== actor) {
          expect(() => post.resolve(actor, 7, NOW)).toThrow(
            expect.objectContaining({ code: 'no_participas_en_este_favor', kind: 'forbidden' }),
          );
          expect(post.snapshot()).toEqual(before);
        } else if (status === 'en_curso') {
          expect(post.resolve(actor, 7, NOW)).toBe('resolved');
          expect(post.snapshot()).toMatchObject({ status: 'resuelta', version: 8, updatedAt: NOW });
          expect(post.pullEvents()).toEqual([
            expect.objectContaining({
              type: FAVOR_RESOLVED_EVENT,
              aggregateId: post.id,
              occurredAt: NOW,
              payload: { autorId: AUTHOR, tomadaPorId: TAKER, zonaId: before.zoneId },
            }),
          ]);
          expect(post.resolve(actor, 7, NOW)).toBe('already_resolved');
          expect(post.version).toBe(8);
        } else if (status === 'resuelta') {
          expect(post.resolve(actor, 1, NOW)).toBe('already_resolved');
          expect(post.snapshot()).toEqual(before);
        } else {
          expect(() => post.resolve(actor, 7, NOW)).toThrow(
            expect.objectContaining({
              code: 'favor_no_en_curso',
              kind: 'conflict',
              extensions: { estadoActual: status },
            }),
          );
          expect(post.snapshot()).toEqual(before);
        }
        expect(post.pullEvents()).toEqual([]);
      });
    }
  }

  it.each(['cancel', 'resolve'] as const)(
    '%s exige la versión vigente antes de cambiar nada',
    (action) => {
      const post = restore(action === 'cancel' ? 'abierta' : 'en_curso');
      const before = post.snapshot();
      expect(() => post[action](AUTHOR, 6, NOW)).toThrow(
        expect.objectContaining({
          code: 'conflicto_de_version',
          currentVersion: 7,
          expectedVersion: 6,
        }),
      );
      expect(post.snapshot()).toEqual(before);
      expect(post.pullEvents()).toEqual([]);
    },
  );
});
