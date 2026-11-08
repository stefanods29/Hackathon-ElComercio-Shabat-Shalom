import type { DomainEvent } from '../../../shared/domain/domain-event.js';
import { BusinessRuleViolation, VersionConflict } from '../../../shared/domain/errors.js';
import { isUuidV7 } from '../../../shared/domain/ids.js';

export const SERVICE_PUBLISHED_EVENT = 'directorio.servicio_publicado';

export interface Coordinates {
  readonly lat: number;
  readonly lng: number;
}

export interface ServiceData {
  readonly categoryId: string;
  readonly title: string;
  readonly description: string | null;
  readonly location: Coordinates;
  readonly showExactLocation: boolean;
  readonly coverageRadiusMeters: number;
  readonly availableInEmergency: boolean;
  readonly attributes: Readonly<Record<string, unknown>>;
}

export interface ServiceProps extends ServiceData {
  readonly id: string;
  readonly providerId: string;
  readonly zoneId: string;
  readonly publicLocation: Coordinates;
  readonly reviewCount: number;
  readonly ratingSum: number;
  readonly average: number;
  readonly rankingScore: number;
  readonly endorsementCount: number;
  readonly zoneEndorsementCount: number;
  readonly version: number;
  readonly createdAt: Date;
  readonly updatedAt: Date;
  readonly deletedAt: Date | null;
  readonly hiddenAt: Date | null;
}

export function publicLocation(location: Coordinates, showExactLocation: boolean): Coordinates {
  const round = (value: number) => Math.round(value * 1000) / 1000;
  return showExactLocation
    ? { ...location }
    : { lat: round(location.lat), lng: round(location.lng) };
}

export function attributesFit(attributes: Readonly<Record<string, unknown>>): boolean {
  return new TextEncoder().encode(JSON.stringify(attributes)).byteLength <= 4096;
}

function validated(data: ServiceData): ServiceData {
  const title = data.title.trim();
  if (title.length < 3 || title.length > 120) {
    throw new BusinessRuleViolation(
      'titulo_invalido',
      'El título debe tener de 3 a 120 caracteres.',
    );
  }
  if (!/^[a-z0-9-]{2,40}$/.test(data.categoryId)) {
    throw new BusinessRuleViolation('categoria_invalida', 'Elige una categoría del directorio.');
  }
  if (data.description !== null && data.description.trim().length > 2000) {
    throw new BusinessRuleViolation(
      'descripcion_invalida',
      'La descripción supera 2000 caracteres.',
    );
  }
  if (
    !Number.isFinite(data.location.lat) ||
    !Number.isFinite(data.location.lng) ||
    Math.abs(data.location.lat) > 90 ||
    Math.abs(data.location.lng) > 180
  ) {
    throw new BusinessRuleViolation('ubicacion_invalida', 'Indica una ubicación válida.');
  }
  if (
    !Number.isInteger(data.coverageRadiusMeters) ||
    data.coverageRadiusMeters < 100 ||
    data.coverageRadiusMeters > 20000
  ) {
    throw new BusinessRuleViolation(
      'radio_invalido',
      'El radio debe estar entre 100 y 20000 metros.',
    );
  }
  if (!attributesFit(data.attributes)) {
    throw new BusinessRuleViolation('atributos_invalidos', 'Los atributos superan 4096 bytes.');
  }
  return {
    ...data,
    title,
    description: data.description?.trim() || null,
    location: { ...data.location },
    attributes: structuredClone(data.attributes),
  };
}

export class Service {
  private events: DomainEvent[] = [];

  private constructor(private props: ServiceProps) {}

  static create(
    data: ServiceData & {
      readonly id: string;
      readonly providerId: string;
      readonly zoneId: string;
    },
    now: Date,
  ): Service {
    if (!isUuidV7(data.id)) {
      throw new BusinessRuleViolation('id_invalido', 'El id del servicio debe ser un UUIDv7.');
    }
    const service = new Service({
      ...data,
      ...validated(data),
      publicLocation: publicLocation(data.location, data.showExactLocation),
      reviewCount: 0,
      ratingSum: 0,
      average: 0,
      rankingScore: 0,
      endorsementCount: 0,
      zoneEndorsementCount: 0,
      version: 1,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      hiddenAt: null,
    });
    service.events.push({
      type: SERVICE_PUBLISHED_EVENT,
      aggregateId: data.id,
      occurredAt: now,
      payload: { proveedorId: data.providerId, zonaId: data.zoneId, categoriaId: data.categoryId },
    });
    return service;
  }

  static restore(props: ServiceProps): Service {
    return new Service(structuredClone(props));
  }

  get id(): string {
    return this.props.id;
  }

  get version(): number {
    return this.props.version;
  }

  snapshot(): ServiceProps {
    return structuredClone(this.props);
  }

  pullEvents(): DomainEvent[] {
    const events = this.events;
    this.events = [];
    return events;
  }

  assertOwner(actorId: string): void {
    if (this.props.providerId !== actorId) {
      throw new BusinessRuleViolation(
        'no_eres_el_dueno',
        'Solo el dueño puede cambiar este servicio.',
        'forbidden',
      );
    }
  }

  edit(actorId: string, seenVersion: number, data: ServiceData, now: Date): void {
    this.assertOwner(actorId);
    if (this.props.deletedAt) {
      throw new BusinessRuleViolation(
        'servicio_retirado',
        'El servicio ya está retirado.',
        'conflict',
      );
    }
    if (this.props.version !== seenVersion) {
      throw new VersionConflict(seenVersion, this.props.version);
    }
    this.props = {
      ...this.props,
      ...validated(data),
      publicLocation: publicLocation(data.location, data.showExactLocation),
      version: this.props.version + 1,
      updatedAt: now,
    };
  }

  withdraw(actorId: string, now: Date): boolean {
    this.assertOwner(actorId);
    if (this.props.deletedAt) return false;
    this.props = {
      ...this.props,
      deletedAt: now,
      updatedAt: now,
      version: this.props.version + 1,
    };
    return true;
  }
}
