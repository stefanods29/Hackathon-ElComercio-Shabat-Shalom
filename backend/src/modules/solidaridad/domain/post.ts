import type { DomainEvent } from '../../../shared/domain/domain-event.js';
import { BusinessRuleViolation, VersionConflict } from '../../../shared/domain/errors.js';
import { isUuidV7 } from '../../../shared/domain/ids.js';

/** Type and status values are part of the contract (API and database) and stay in Spanish. */
export const POST_TYPES = [
  'ofrezco',
  'necesito',
  'presto',
  'dono',
  'intercambio',
  'movilidad',
] as const;
export type PostType = (typeof POST_TYPES)[number];

export const POST_STATUSES = ['abierta', 'en_curso', 'resuelta', 'cancelada'] as const;
export type PostStatus = (typeof POST_STATUSES)[number];

/** Minimum trust level to publish on the wall (section 5.5 of the architecture). */
export const MIN_TRUST_LEVEL_TO_PUBLISH = 1;

export interface Coordinates {
  readonly lat: number;
  readonly lng: number;
}

export interface PostProps {
  readonly id: string;
  readonly authorId: string;
  readonly zoneId: string;
  readonly type: PostType;
  readonly category: string;
  readonly title: string;
  readonly description: string | null;
  readonly location: Coordinates | null;
  readonly status: PostStatus;
  readonly takenById: string | null;
  readonly version: number;
  readonly expiresAt: Date | null;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

export interface NewPostData {
  readonly id: string;
  readonly authorId: string;
  readonly zoneId: string;
  readonly type: PostType;
  readonly category: string;
  readonly title: string;
  readonly description?: string | null;
  readonly location?: Coordinates | null;
  readonly expiresAt?: Date | null;
}

/** Event names and payload keys are a contract with the workers and stay in Spanish. */
export const POST_CREATED_EVENT = 'solidaridad.publicacion_creada';
export const FAVOR_TAKEN_EVENT = 'solidaridad.favor_tomado';
export const POST_CANCELLED_EVENT = 'solidaridad.publicacion_cancelada';
export const FAVOR_RESOLVED_EVENT = 'solidaridad.favor_resuelto';

/** ≈100 m: enough for "near you" without exposing where someone lives. */
export function approximate(coordinates: Coordinates): Coordinates {
  const round = (value: number) => Math.round(value * 1000) / 1000;
  return { lat: round(coordinates.lat), lng: round(coordinates.lng) };
}

/** The clearest rejection for the second neighbor who tries to take the same favor. */
export function favorNotAvailable(currentStatus: PostStatus): BusinessRuleViolation {
  return new BusinessRuleViolation(
    'favor_no_disponible',
    'Otro vecino ya tomó este favor o ya no está disponible.',
    'conflict',
    { estadoActual: currentStatus },
  );
}

/**
 * Aggregate of the favor wall. It protects its rules:
 * - the id is generated on the phone (UUIDv7) and never repeats;
 * - a favor is taken by one neighbor only, and never by its own author;
 * - every change bumps the version (optimistic concurrency).
 */
export class Post {
  private events: DomainEvent[] = [];

  private constructor(private props: PostProps) {}

  static create(data: NewPostData, now: Date): Post {
    if (!isUuidV7(data.id)) {
      throw new BusinessRuleViolation(
        'id_invalido',
        'El id de la publicación debe ser un UUIDv7 generado en el celular.',
      );
    }
    const title = data.title.trim();
    if (title.length < 3 || title.length > 120) {
      throw new BusinessRuleViolation(
        'titulo_invalido',
        'El título debe tener entre 3 y 120 caracteres.',
      );
    }
    if (data.expiresAt && data.expiresAt.getTime() <= now.getTime()) {
      throw new BusinessRuleViolation(
        'vencimiento_en_el_pasado',
        'La fecha de vencimiento debe ser futura.',
      );
    }
    const post = new Post({
      id: data.id,
      authorId: data.authorId,
      zoneId: data.zoneId,
      type: data.type,
      category: data.category.trim().toLowerCase(),
      title,
      description: data.description?.trim() || null,
      location: data.location ? approximate(data.location) : null,
      status: 'abierta',
      takenById: null,
      version: 1,
      expiresAt: data.expiresAt ?? null,
      createdAt: now,
      updatedAt: now,
    });
    post.record(POST_CREATED_EVENT, now, {
      zonaId: data.zoneId,
      tipo: data.type,
      categoria: post.props.category,
    });
    return post;
  }

  static restore(props: PostProps): Post {
    return new Post(props);
  }

  get id(): string {
    return this.props.id;
  }

  get version(): number {
    return this.props.version;
  }

  snapshot(): PostProps {
    return this.props;
  }

  /** Hands over and clears the pending events: the use case stores them in the outbox. */
  pullEvents(): DomainEvent[] {
    const pending = this.events;
    this.events = [];
    return pending;
  }

  /**
   * A neighbor takes the favor with the version seen on the phone.
   * Repeating the same action by the same neighbor is not an error (domain idempotency).
   */
  take(neighborId: string, seenVersion: number, now: Date): 'taken' | 'already_mine' {
    const current = this.props;
    if (current.status === 'en_curso' && current.takenById === neighborId) {
      return 'already_mine';
    }
    if (current.authorId === neighborId) {
      throw new BusinessRuleViolation(
        'no_puedes_tomar_tu_publicacion',
        'No puedes tomar una publicación que tú mismo hiciste.',
        'forbidden',
      );
    }
    if (current.status !== 'abierta') {
      throw favorNotAvailable(current.status);
    }
    if (current.version !== seenVersion) {
      throw new VersionConflict(seenVersion, current.version);
    }
    if (current.expiresAt && current.expiresAt.getTime() <= now.getTime()) {
      throw new BusinessRuleViolation('favor_vencido', 'Este favor ya venció.', 'conflict');
    }
    this.props = {
      ...current,
      status: 'en_curso',
      takenById: neighborId,
      version: current.version + 1,
      updatedAt: now,
    };
    this.record(FAVOR_TAKEN_EVENT, now, {
      autorId: current.authorId,
      tomadaPorId: neighborId,
      zonaId: current.zoneId,
    });
    return 'taken';
  }

  cancel(actorId: string, seenVersion: number, now: Date): 'cancelled' | 'already_cancelled' {
    const current = this.props;
    if (current.authorId !== actorId) {
      throw new BusinessRuleViolation(
        'no_eres_el_autor',
        'Solo el autor puede cancelar esta publicación.',
        'forbidden',
      );
    }
    if (current.status === 'cancelada') return 'already_cancelled';
    if (current.status !== 'abierta') {
      throw new BusinessRuleViolation(
        'no_se_puede_cancelar',
        'Solo puedes cancelar una publicación abierta.',
        'conflict',
        { estadoActual: current.status },
      );
    }
    if (current.version !== seenVersion) throw new VersionConflict(seenVersion, current.version);
    this.props = { ...current, status: 'cancelada', version: current.version + 1, updatedAt: now };
    this.record(POST_CANCELLED_EVENT, now, { autorId: current.authorId, zonaId: current.zoneId });
    return 'cancelled';
  }

  resolve(actorId: string, seenVersion: number, now: Date): 'resolved' | 'already_resolved' {
    const current = this.props;
    if (current.authorId !== actorId && current.takenById !== actorId) {
      throw new BusinessRuleViolation(
        'no_participas_en_este_favor',
        'Solo el autor o quien tomó el favor puede resolverlo.',
        'forbidden',
      );
    }
    if (current.status === 'resuelta') return 'already_resolved';
    if (current.status !== 'en_curso') {
      throw new BusinessRuleViolation(
        'favor_no_en_curso',
        'Solo puedes resolver un favor en curso.',
        'conflict',
        { estadoActual: current.status },
      );
    }
    if (current.version !== seenVersion) throw new VersionConflict(seenVersion, current.version);
    this.props = { ...current, status: 'resuelta', version: current.version + 1, updatedAt: now };
    this.record(FAVOR_RESOLVED_EVENT, now, {
      autorId: current.authorId,
      tomadaPorId: current.takenById,
      zonaId: current.zoneId,
    });
    return 'resolved';
  }

  private record(type: string, occurredAt: Date, payload: Record<string, unknown>): void {
    this.events.push({ type, aggregateId: this.props.id, occurredAt, payload });
  }
}
