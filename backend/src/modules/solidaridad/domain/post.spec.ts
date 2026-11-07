import { BusinessRuleViolation, VersionConflict } from '../../../shared/domain/errors.js';
import { newId } from '../../../shared/domain/ids.js';
import { FAVOR_TAKEN_EVENT, POST_CREATED_EVENT, Post, approximate } from './post.js';

const NOW = new Date('2026-11-06T15:00:00Z');
const AUTHOR = '01970000-0000-7000-8000-0000000000a1';
const NEIGHBOR = '01970000-0000-7000-8000-0000000000b1';
const OTHER_NEIGHBOR = '01970000-0000-7000-8000-0000000000c1';
const ZONE = '01970000-0000-7000-8000-000000000001';

function newPost(changes: Partial<Parameters<typeof Post.create>[0]> = {}): Post {
  return Post.create(
    {
      id: newId(),
      authorId: AUTHOR,
      zoneId: ZONE,
      type: 'presto',
      category: 'Herramientas',
      title: 'Presto taladro',
      ...changes,
    },
    NOW,
  );
}

function codeOf(action: () => unknown): string | undefined {
  try {
    action();
  } catch (error) {
    if (error instanceof BusinessRuleViolation || error instanceof VersionConflict) {
      return error.code;
    }
    throw error;
  }
  return undefined;
}

describe('Post', () => {
  describe('create', () => {
    it('nace abierta, en versión 1, con la categoría normalizada y un evento de creación', () => {
      const post = newPost();
      const data = post.snapshot();
      expect(data.status).toBe('abierta');
      expect(data.version).toBe(1);
      expect(data.category).toBe('herramientas');
      expect(post.pullEvents().map((event) => event.type)).toEqual([POST_CREATED_EVENT]);
      expect(post.pullEvents()).toEqual([]);
    });

    it('exige un UUIDv7 generado en el celular', () => {
      expect(codeOf(() => newPost({ id: '3f2a1d8e-1c9b-4a7e-9d2f-0b6c5e4a3d21' }))).toBe(
        'id_invalido',
      );
    });

    it('rechaza títulos muy cortos y vencimientos en el pasado', () => {
      expect(codeOf(() => newPost({ title: ' a ' }))).toBe('titulo_invalido');
      expect(codeOf(() => newPost({ expiresAt: new Date('2026-11-06T14:59:59Z') }))).toBe(
        'vencimiento_en_el_pasado',
      );
    });

    it('guarda solo una ubicación aproximada (≈100 m)', () => {
      const post = newPost({ location: { lat: -12.085_678_9, lng: -77.034_567_1 } });
      expect(post.snapshot().location).toEqual({ lat: -12.086, lng: -77.035 });
      expect(approximate({ lat: 1.000_49, lng: 2.000_51 })).toEqual({ lat: 1, lng: 2.001 });
    });
  });

  describe('take', () => {
    it('pasa a en_curso, sube la versión y registra el evento', () => {
      const post = newPost();
      post.pullEvents();
      expect(post.take(NEIGHBOR, 1, NOW)).toBe('taken');
      const data = post.snapshot();
      expect(data.status).toBe('en_curso');
      expect(data.takenById).toBe(NEIGHBOR);
      expect(data.version).toBe(2);
      expect(post.pullEvents().map((event) => event.type)).toEqual([FAVOR_TAKEN_EVENT]);
    });

    it('es idempotente para el mismo vecino', () => {
      const post = newPost();
      post.take(NEIGHBOR, 1, NOW);
      expect(post.take(NEIGHBOR, 1, NOW)).toBe('already_mine');
      expect(post.version).toBe(2);
    });

    it('rechaza al segundo vecino con un motivo claro, aunque traiga la versión vieja', () => {
      const post = newPost();
      post.take(NEIGHBOR, 1, NOW);
      expect(codeOf(() => post.take(OTHER_NEIGHBOR, 1, NOW))).toBe('favor_no_disponible');
    });

    it('detecta que la publicación cambió desde que el vecino la vio', () => {
      const post = Post.restore({ ...newPost().snapshot(), version: 3 });
      expect(codeOf(() => post.take(NEIGHBOR, 2, NOW))).toBe('conflicto_de_version');
    });

    it('no deja que el autor tome su propia publicación ni tomar favores vencidos', () => {
      expect(codeOf(() => newPost().take(AUTHOR, 1, NOW))).toBe('no_puedes_tomar_tu_publicacion');
      const expiring = newPost({ expiresAt: new Date('2026-11-06T16:00:00Z') });
      expect(codeOf(() => expiring.take(NEIGHBOR, 1, new Date('2026-11-06T16:00:01Z')))).toBe(
        'favor_vencido',
      );
    });
  });
});
