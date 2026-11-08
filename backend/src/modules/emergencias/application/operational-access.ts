import { Inject, Injectable } from '@nestjs/common';
import type { Actor } from '../../../shared/auth/actor.js';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { BusinessRuleViolation, ResourceNotFound } from '../../../shared/domain/errors.js';
import { OPERATIONAL_IDENTITY, type OperationalIdentity } from '../../identidad/index.js';
import type { DutyShift, OperationalGrant, OperationalRole } from '../domain/emergency.js';
import { OPERATIONS_STORE, type OperationsStore } from './ports.js';

export interface EligibleOperator {
  readonly id: string;
  readonly name: string;
  readonly role: OperationalRole;
  readonly grant: OperationalGrant;
  readonly shift: DutyShift | null;
}

@Injectable()
export class OperationalAccess {
  constructor(
    @Inject(OPERATIONS_STORE) private readonly operations: OperationsStore,
    @Inject(OPERATIONAL_IDENTITY) private readonly identity: OperationalIdentity,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}
  requireAdministrator(actor: Actor): void {
    if (!actor.roles.includes('administrador') || actor.trustLevel < 3) {
      throw new BusinessRuleViolation(
        'rol_requerido',
        'Se requiere una cuenta administradora de nivel 3.',
        'forbidden',
      );
    }
  }
  requireZone(actor: Actor, zoneId: string): void {
    if (actor.zoneId !== zoneId) throw new ResourceNotFound('la zona', zoneId);
  }
  async eligible(
    tx: TransactionContext,
    zoneId: string,
    role?: OperationalRole,
  ): Promise<EligibleOperator[]> {
    const now = this.clock.now();
    const grants = await this.operations.grants(tx, zoneId, now);
    const shifts = await this.operations.shifts(tx, zoneId, now);
    const result: EligibleOperator[] = [];
    for (const grant of grants) {
      if (role && grant.role !== role) continue;
      const account = await this.identity.find(tx, grant.userId);
      if (
        !account ||
        account.zoneId !== zoneId ||
        account.trustLevel < 3 ||
        !account.roles.includes(grant.role)
      )
        continue;
      const shift =
        shifts.find(
          (item) =>
            item.userId === account.id &&
            item.role === grant.role &&
            item.endedAt === null &&
            item.startsAt <= now &&
            item.endsAt > now,
        ) ?? null;
      result.push({ id: account.id, name: account.displayName, role: grant.role, grant, shift });
    }
    return result;
  }
  async require(
    tx: TransactionContext,
    actor: Actor,
    zoneId: string,
    roles: readonly OperationalRole[],
    onDuty = true,
  ): Promise<EligibleOperator> {
    this.requireZone(actor, zoneId);
    const eligible = (await this.eligible(tx, zoneId)).find(
      (person) =>
        person.id === actor.id &&
        actor.trustLevel >= 3 &&
        actor.roles.includes(person.role) &&
        roles.includes(person.role) &&
        (!onDuty || person.shift !== null),
    );
    if (!eligible)
      throw new BusinessRuleViolation(
        'habilitacion_requerida',
        'Se requiere habilitación vigente y un turno para esta acción.',
        'forbidden',
      );
    return eligible;
  }
  async coverage(tx: TransactionContext, zoneId: string) {
    const coordinators = await this.eligible(tx, zoneId, 'coordinador');
    const onDuty = coordinators.filter((item) => item.shift !== null);
    return { coordinators, onDuty, covered: coordinators.length >= 2 && onDuty.length > 0 };
  }
  async requireCoverage(tx: TransactionContext, zoneId: string): Promise<EligibleOperator[]> {
    const coverage = await this.coverage(tx, zoneId);
    if (!coverage.covered)
      throw new BusinessRuleViolation(
        'zona_sin_cobertura',
        'La zona todavía no tiene coordinación disponible. Consulta el directorio de emergencia.',
        'conflict',
        { accionAlternativa: 'directorio_emergencia' },
      );
    return coverage.onDuty;
  }
  assignmentExpiry(person: EligibleOperator, requestExpiry: Date): Date {
    return new Date(
      Math.min(
        requestExpiry.getTime(),
        person.grant.expiresAt.getTime(),
        person.shift?.endsAt.getTime() ?? 0,
      ),
    );
  }
}
