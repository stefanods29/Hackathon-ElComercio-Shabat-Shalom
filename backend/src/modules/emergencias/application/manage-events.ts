import { Inject, Injectable } from '@nestjs/common';
import type { Actor } from '../../../shared/auth/actor.js';
import { AccountAccess } from '../../../shared/auth/account-access.js';
import { APP_CONFIG, type AppConfig } from '../../../shared/config/app-config.js';
import {
  UNIT_OF_WORK,
  type TransactionContext,
  type UnitOfWork,
} from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { newId } from '../../../shared/domain/ids.js';
import { BusinessRuleViolation, ResourceNotFound } from '../../../shared/domain/errors.js';
import { OUTBOX_WRITER, type OutboxWriter } from '../../../shared/outbox/outbox.js';
import { OPERATIONAL_IDENTITY, type OperationalIdentity } from '../../identidad/index.js';
import { assertVersion, type EmergencyEvent } from '../domain/emergency.js';
import {
  AUDIT_STORE,
  type AuditStore,
  EVENT_STORE,
  type EventStore,
  type OfficialAlert,
} from './ports.js';
import { OperationalAccess } from './operational-access.js';

@Injectable()
export class ManageEvents {
  constructor(
    @Inject(UNIT_OF_WORK) private readonly uow: UnitOfWork,
    @Inject(EVENT_STORE) private readonly events: EventStore,
    @Inject(AUDIT_STORE) private readonly audit: AuditStore,
    @Inject(OUTBOX_WRITER) private readonly outbox: OutboxWriter,
    @Inject(OPERATIONAL_IDENTITY) private readonly identity: OperationalIdentity,
    @Inject(CLOCK) private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    private readonly access: OperationalAccess,
    private readonly accounts: AccountAccess,
  ) {}
  requireEnabled(): void {
    if (!this.config.EMERGENCIES_ENABLED)
      throw new BusinessRuleViolation(
        'operacion_no_habilitada',
        'La coordinación de emergencias todavía no está habilitada. Consulta el directorio de emergencia.',
        'conflict',
        { accionAlternativa: 'directorio_emergencia' },
      );
  }
  async list(zoneId: string, actor: Actor) {
    this.access.requireZone(actor, zoneId);
    return this.uow.run((tx) => this.events.list(tx, zoneId));
  }
  async coverage(zoneId: string, actor: Actor) {
    this.access.requireZone(actor, zoneId);
    return this.uow.run(async (tx) => {
      const coverage = await this.access.coverage(tx, zoneId);
      const event = await this.events.current(tx, zoneId);
      return {
        zonaId: zoneId,
        coordinadoresActivos: coverage.coordinators.length,
        coordinadoresDeTurno: coverage.onDuty.length,
        habilitada:
          this.config.EMERGENCIES_ENABLED && coverage.covered && event?.state === 'emergencia',
        eventoId: event?.id ?? null,
        modo: event?.state ?? 'normal',
        actualizadoEn: this.clock.now().toISOString(),
      };
    });
  }
  async activate(
    input: { id: string; zoneId: string; level: number },
    actor: Actor,
  ): Promise<EmergencyEvent> {
    this.requireEnabled();
    return this.uow.run(async (tx) => {
      await this.accounts.requireActiveWrite(tx, actor.id);
      await this.events.lockZone(tx, input.zoneId);
      await this.access.require(tx, actor, input.zoneId, ['coordinador'], false);
      const existing = await this.events.find(tx, input.id);
      if (existing) {
        if (existing.zoneId !== input.zoneId || existing.level !== input.level)
          throw new BusinessRuleViolation(
            'id_en_uso',
            'Ese identificador corresponde a otro evento.',
            'conflict',
          );
        return existing;
      }
      return this.insert(tx, input, actor.id, 'coordinador', null);
    });
  }
  private async insert(
    tx: TransactionContext,
    input: { id: string; zoneId: string; level: number },
    actorId: string | null,
    source: string,
    externalId: string | null,
  ) {
    if (!(await this.identity.zoneExists(tx, input.zoneId)))
      throw new ResourceNotFound('la zona', input.zoneId);
    if (await this.events.current(tx, input.zoneId))
      throw new BusinessRuleViolation(
        'evento_activo',
        'La zona ya tiene un evento abierto.',
        'conflict',
      );
    const now = this.clock.now();
    const event: EmergencyEvent = {
      ...input,
      state: 'emergencia',
      version: 1,
      createdAt: now,
      closedAt: null,
      source,
      externalId,
      summary: null,
    };
    await this.events.insert(tx, event, actorId);
    await this.audit.record(
      tx,
      actorId,
      actorId ? 'coordinador' : 'sistema',
      null,
      `evento_activado:${event.id}`,
      now,
    );
    await this.outbox.record(tx, 'emergencias', [
      {
        type: 'emergencias.evento_activado',
        aggregateId: event.id,
        occurredAt: now,
        payload: { zonaId: event.zoneId, nivel: event.level },
      },
    ]);
    return event;
  }
  async ingest(alert: OfficialAlert): Promise<void> {
    this.requireEnabled();
    await this.uow.run(async (tx) => {
      await this.events.lockZone(tx, alert.zoneId);
      // Recording is transactional: a failure leaves the reference retryable.
      const reference = `${this.config.EMERGENCY_ALERT_SOURCE}:${alert.externalId}:${alert.zoneId}`;
      if (!(await this.events.processedAlert(tx, reference, this.clock.now()))) return;
      if (await this.events.current(tx, alert.zoneId)) return;
      await this.insert(
        tx,
        { id: newId(), zoneId: alert.zoneId, level: alert.level },
        null,
        this.config.EMERGENCY_ALERT_SOURCE,
        alert.externalId,
      );
    });
  }
  async close(id: string, expected: number, reason: string, actor: Actor): Promise<EmergencyEvent> {
    return this.uow.run(async (tx) => {
      await this.accounts.requireActiveWrite(tx, actor.id);
      const event = await this.events.find(tx, id);
      if (!event) throw new ResourceNotFound('el evento', id);
      await this.events.lockZone(tx, event.zoneId);
      await this.access.require(tx, actor, event.zoneId, ['coordinador'], false);
      const current = await this.events.find(tx, id);
      if (!current) throw new ResourceNotFound('el evento', id);
      assertVersion(expected, current.version);
      if (current.state !== 'emergencia')
        throw new BusinessRuleViolation(
          'transicion_invalida',
          'El evento ya está en cierre.',
          'conflict',
        );
      const now = this.clock.now();
      const closed = await this.events.close(tx, current, now, reason);
      await this.audit.record(tx, actor.id, 'coordinador', null, `evento_en_cierre:${id}`, now);
      // The reason remains private, never in the event consumed by notifications.
      await this.outbox.record(tx, 'emergencias', [
        {
          type: 'emergencias.evento_en_cierre',
          aggregateId: id,
          occurredAt: now,
          payload: { zonaId: event.zoneId },
        },
      ]);
      return closed;
    });
  }
  async summary(id: string, actor: Actor) {
    return this.uow.run(async (tx) => {
      const event = await this.events.find(tx, id);
      if (!event) throw new ResourceNotFound('el evento', id);
      if (actor.roles.includes('administrador')) this.access.requireAdministrator(actor);
      else await this.access.require(tx, actor, event.zoneId, ['coordinador'], false);
      return event.summary ?? { estado: event.state };
    });
  }
}
