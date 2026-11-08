import { BusinessRuleViolation } from '../../../shared/domain/errors.js';

export interface ProviderData {
  readonly publicName: string;
  readonly description: string | null;
}

export interface ProviderProps extends ProviderData {
  readonly id: string;
  readonly zoneId: string;
  readonly createdAt: Date;
  readonly updatedAt: Date;
  readonly deletedAt: Date | null;
  readonly hiddenAt: Date | null;
}

function validated(data: ProviderData): ProviderData {
  const publicName = data.publicName.trim();
  if (publicName.length < 2 || publicName.length > 60) {
    throw new BusinessRuleViolation(
      'nombre_invalido',
      'El nombre debe tener de 2 a 60 caracteres.',
    );
  }
  if (data.description !== null && data.description.trim().length > 500) {
    throw new BusinessRuleViolation(
      'descripcion_invalida',
      'La descripción supera 500 caracteres.',
    );
  }
  return { publicName, description: data.description?.trim() || null };
}

export class ProviderProfile {
  private constructor(private props: ProviderProps) {}

  static create(id: string, zoneId: string, data: ProviderData, now: Date): ProviderProfile {
    return new ProviderProfile({
      ...validated(data),
      id,
      zoneId,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      hiddenAt: null,
    });
  }

  static restore(props: ProviderProps): ProviderProfile {
    return new ProviderProfile(structuredClone(props));
  }

  snapshot(): ProviderProps {
    return structuredClone(this.props);
  }

  update(actorId: string, zoneId: string, data: ProviderData, now: Date): void {
    if (actorId !== this.props.id) {
      throw new BusinessRuleViolation(
        'no_eres_el_dueno',
        'Solo el dueño puede cambiar este perfil.',
        'forbidden',
      );
    }
    this.props = { ...this.props, ...validated(data), zoneId, updatedAt: now };
  }
}
