import { Inject, Injectable } from '@nestjs/common';
import type { Actor } from '../../../shared/auth/actor.js';
import { AccountAccess } from '../../../shared/auth/account-access.js';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { BusinessRuleViolation, ResourceNotFound } from '../../../shared/domain/errors.js';
import { OPERATIONAL_IDENTITY, type OperationalIdentity } from '../../identidad/index.js';
import {
  assertVersion,
  requireFutureWindow,
  type DutyShift,
  type OperationalGrant,
  type SupportGroup,
} from '../domain/emergency.js';
import {
  AUDIT_STORE,
  type AuditStore,
  EVENT_STORE,
  type EventStore,
  OPERATIONS_STORE,
  type OperationsStore,
  type GrantEvidence,
} from './ports.js';
import { OperationalAccess } from './operational-access.js';

@Injectable()
export class ManageOperations {
  constructor(
    @Inject(UNIT_OF_WORK) private readonly uow: UnitOfWork,
    @Inject(OPERATIONS_STORE) private readonly operations: OperationsStore,
    @Inject(EVENT_STORE) private readonly events: EventStore,
    @Inject(AUDIT_STORE) private readonly audit: AuditStore,
    @Inject(OPERATIONAL_IDENTITY) private readonly identity: OperationalIdentity,
    @Inject(CLOCK) private readonly clock: Clock,
    private readonly access: OperationalAccess,
    private readonly accounts: AccountAccess,
  ) {}
  async grant(
    input: Omit<OperationalGrant, 'revokedAt' | 'version'> &
      Omit<GrantEvidence, 'reviewedBy'> & { expected?: number },
    actor: Actor,
  ) {
    this.access.requireAdministrator(actor);
    return this.uow.run(async (tx) => {
      await this.accounts.requireActiveWrite(tx, actor.id);
      await this.operations.lockUser(tx, input.userId);
      const account = await this.identity.find(tx, input.userId);
      const now = this.clock.now();
      if (!account || account.zoneId !== input.zoneId)
        throw new ResourceNotFound('la cuenta operativa', input.userId);
      if (
        [input.dniReviewedAt, input.trainedAt, input.confidentialityAt].some((at) => at > now) ||
        input.expiresAt <= now ||
        input.expiresAt.getTime() > now.getTime() + 365 * 86400000
      ) {
        throw new BusinessRuleViolation(
          'acreditacion_invalida',
          'Registra las revisiones ya realizadas y una vigencia de hasta un año.',
        );
      }
      const existing = await this.operations.grant(tx, input.id);
      if (
        existing &&
        (existing.userId !== input.userId ||
          existing.zoneId !== input.zoneId ||
          existing.role !== input.role)
      ) {
        throw new BusinessRuleViolation(
          'id_en_uso',
          'Ese identificador corresponde a otra habilitación.',
          'conflict',
        );
      }
      const subject = await this.operations.grantFor(tx, input.userId, input.zoneId, input.role);
      if (subject && subject.id !== input.id)
        throw new BusinessRuleViolation(
          'id_en_uso',
          'Usa el identificador de la habilitación existente para renovarla.',
          'conflict',
          { habilitacionId: subject.id },
        );
      if (existing) {
        if (input.expected === undefined) {
          if (!existing.revokedAt && existing.expiresAt.getTime() === input.expiresAt.getTime())
            return existing;
          throw new BusinessRuleViolation(
            'version_requerida',
            'La renovación requiere versionVista.',
            'conflict',
          );
        }
        assertVersion(input.expected, existing.version);
      } else if (input.expected !== undefined)
        throw new ResourceNotFound('la habilitación', input.id);
      const grant = await this.operations.saveGrant(
        tx,
        { ...input, version: 1, revokedAt: null },
        { ...input, reviewedBy: actor.id },
      );
      await this.identity.certify(tx, input.userId, input.role, now);
      await this.audit.record(
        tx,
        actor.id,
        'administrador',
        null,
        `habilitacion_registrada:${grant.id}`,
        now,
      );
      return grant;
    });
  }
  async revoke(id: string, expected: number, actor: Actor) {
    this.access.requireAdministrator(actor);
    return this.uow.run(async (tx) => {
      await this.accounts.requireActiveWrite(tx, actor.id);
      const grant = await this.operations.grant(tx, id);
      if (!grant) throw new ResourceNotFound('la habilitación', id);
      assertVersion(expected, grant.version);
      await this.events.lockZone(tx, grant.zoneId);
      const now = this.clock.now();
      const revoked = await this.operations.revoke(tx, grant, now);
      if (grant.role !== 'curador')
        await this.operations.finishAssignments(tx, grant.userId, now, grant.role);
      if ((await this.operations.activeGrants(tx, grant.userId, grant.role, now)) === 0)
        await this.identity.removeRole(tx, grant.userId, grant.role, now);
      await this.audit.record(
        tx,
        actor.id,
        'administrador',
        null,
        `habilitacion_revocada:${id}`,
        now,
      );
      return revoked;
    });
  }
  async board(zoneId: string, actor: Actor) {
    return this.uow.run(async (tx) => {
      await this.access.require(tx, actor, zoneId, ['coordinador'], false);
      const now = this.clock.now();
      return {
        people: await this.access.eligible(tx, zoneId),
        shifts: await this.operations.shifts(tx, zoneId, now),
        updatedAt: now,
      };
    });
  }
  async createShift(input: Omit<DutyShift, 'endedAt' | 'version'>, actor: Actor) {
    return this.uow.run(async (tx) => {
      await this.accounts.requireActiveWrite(tx, actor.id);
      await this.events.lockZone(tx, input.zoneId);
      await this.access.require(tx, actor, input.zoneId, ['coordinador'], false);
      await this.operations.lockUser(tx, input.userId);
      const now = this.clock.now();
      requireFutureWindow(input.startsAt, input.endsAt, now);
      const person = (await this.access.eligible(tx, input.zoneId, input.role)).find(
        (item) => item.id === input.userId,
      );
      if (!person || person.grant.expiresAt < input.endsAt)
        throw new BusinessRuleViolation(
          'habilitacion_requerida',
          'La habilitación debe cubrir todo el turno.',
          'forbidden',
        );
      const existing = await this.operations.shift(tx, input.id);
      if (existing) {
        if (
          existing.userId === input.userId &&
          existing.zoneId === input.zoneId &&
          existing.role === input.role &&
          existing.startsAt.getTime() === input.startsAt.getTime() &&
          existing.endsAt.getTime() === input.endsAt.getTime()
        )
          return existing;
        throw new BusinessRuleViolation(
          'id_en_uso',
          'Ese identificador corresponde a otro turno.',
          'conflict',
        );
      }
      if (await this.operations.overlapsShift(tx, { ...input, endedAt: null, version: 1 })) {
        throw new BusinessRuleViolation(
          'turno_superpuesto',
          'La persona ya tiene un turno en ese horario.',
          'conflict',
        );
      }
      const shift = await this.operations.insertShift(tx, { ...input, endedAt: null, version: 1 });
      await this.audit.record(tx, actor.id, 'coordinador', null, `turno_creado:${shift.id}`, now);
      return shift;
    });
  }
  async endShift(id: string, expected: number, actor: Actor) {
    return this.uow.run(async (tx) => {
      await this.accounts.requireActiveWrite(tx, actor.id);
      const shift = await this.operations.shift(tx, id);
      if (!shift) throw new ResourceNotFound('el turno', id);
      await this.events.lockZone(tx, shift.zoneId);
      await this.access.require(tx, actor, shift.zoneId, ['coordinador'], false);
      assertVersion(expected, shift.version);
      const now = this.clock.now();
      const ended = await this.operations.endShift(tx, shift, now);
      if (
        shift.role !== 'curador' &&
        shift.startsAt <= now &&
        shift.endsAt > now &&
        !shift.endedAt
      ) {
        await this.operations.finishAssignments(tx, shift.userId, now, shift.role);
      }
      await this.audit.record(tx, actor.id, 'coordinador', null, `turno_finalizado:${id}`, now);
      return ended;
    });
  }
  async groups(zoneId: string, actor: Actor) {
    return this.uow.run(async (tx) => {
      await this.access.require(tx, actor, zoneId, ['coordinador'], false);
      return this.operations.groups(tx, zoneId);
    });
  }
  async saveGroup(
    input: {
      id: string;
      zoneId?: string;
      name?: string;
      members: readonly string[];
      expected?: number;
    },
    actor: Actor,
  ): Promise<SupportGroup> {
    this.access.requireAdministrator(actor);
    return this.uow.run(async (tx) => {
      await this.accounts.requireActiveWrite(tx, actor.id);
      const existing = await this.operations.group(tx, input.id);
      if (input.expected !== undefined && !existing)
        throw new ResourceNotFound('el grupo', input.id);
      if (existing && input.expected !== undefined) assertVersion(input.expected, existing.version);
      if (existing && input.zoneId && existing.zoneId !== input.zoneId)
        throw new ResourceNotFound('el grupo', input.id);
      if (existing && input.expected === undefined) {
        if (
          existing.name === input.name &&
          JSON.stringify([...existing.members].sort()) ===
            JSON.stringify([...new Set(input.members)].sort())
        )
          return existing;
        throw new BusinessRuleViolation(
          'id_en_uso',
          'Ese grupo ya existe. Actualiza los miembros con versionVista.',
          'conflict',
        );
      }
      const zoneId = existing?.zoneId ?? input.zoneId;
      if (!zoneId || !(await this.identity.zoneExists(tx, zoneId)))
        throw new ResourceNotFound('la zona', zoneId ?? input.id);
      await this.events.lockZone(tx, zoneId);
      const candidates = await this.access.eligible(tx, zoneId, 'brigadista');
      const members = [...new Set(input.members)];
      if (members.some((id) => !candidates.some((person) => person.id === id)))
        throw new BusinessRuleViolation(
          'miembro_no_habilitado',
          'Todos los miembros deben estar verificados como brigadistas.',
        );
      const name = existing?.name ?? input.name;
      if (!name) throw new BusinessRuleViolation('nombre_requerido', 'Indica el nombre del grupo.');
      const group = await this.operations.saveGroup(tx, {
        id: input.id,
        zoneId,
        name,
        members,
        verifiedAt: existing?.verifiedAt ?? this.clock.now(),
        version: (existing?.version ?? 0) + 1,
      });
      await this.audit.record(
        tx,
        actor.id,
        'administrador',
        null,
        `grupo_actualizado:${group.id}`,
        this.clock.now(),
      );
      return group;
    });
  }
  async support(zoneId: string, zones: readonly string[], actor: Actor) {
    this.access.requireAdministrator(actor);
    return this.uow.run(async (tx) => {
      await this.accounts.requireActiveWrite(tx, actor.id);
      await this.events.lockZone(tx, zoneId);
      for (const id of [zoneId, ...zones])
        if (!(await this.identity.zoneExists(tx, id))) throw new ResourceNotFound('la zona', id);
      if (zones.includes(zoneId))
        throw new BusinessRuleViolation(
          'zona_apoyo_invalida',
          'Selecciona zonas de apoyo diferentes de la zona de origen.',
        );
      const unique = [...new Set(zones)];
      await this.operations.setSupportZones(tx, zoneId, unique);
      await this.audit.record(
        tx,
        actor.id,
        'administrador',
        null,
        'apoyo_zonas_actualizado',
        this.clock.now(),
      );
      return { zonas: unique };
    });
  }
  async auditLog(actor: Actor, cursor: string | undefined, limit: number) {
    this.access.requireAdministrator(actor);
    return this.uow.run(async (tx) => {
      await this.audit.record(
        tx,
        actor.id,
        'administrador',
        null,
        'auditoria_consultada',
        this.clock.now(),
      );
      return this.audit.list(tx, cursor, limit);
    });
  }
}
