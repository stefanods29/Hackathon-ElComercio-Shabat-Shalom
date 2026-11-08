import { Inject, Injectable, type OnModuleInit } from '@nestjs/common';
import { v5 as uuidv5 } from 'uuid';
import { z } from 'zod';
import { APP_CONFIG, type AppConfig } from '../../../shared/config/app-config.js';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { newId } from '../../../shared/domain/ids.js';
import { OUTBOX_WRITER, type OutboxWriter } from '../../../shared/outbox/outbox.js';
import { JOB_QUEUE, type JobQueue } from '../../../shared/queues/job-queue.js';
import { JobHandlerRegistry } from '../../../shared/queues/job-handler.registry.js';
import {
  SEND_NOTIFICATION_JOB,
  URGENT_NOTICE_JOB,
  type UrgentTemplate,
} from '../../notificaciones/index.js';
import type { HelpRequest } from '../domain/emergency.js';
import {
  AUDIT_STORE,
  type AuditStore,
  EVENT_STORE,
  type EventStore,
  OFFICIAL_ALERT_SOURCE,
  type OfficialAlertSource,
  OPERATIONS_STORE,
  type OperationsStore,
  REQUEST_STORE,
  type RequestStore,
  RESOURCE_STORE,
  type ResourceStore,
} from './ports.js';
import { ManageEvents } from './manage-events.js';
import { ManageHelpRequests } from './manage-help-requests.js';
import { OperationalAccess } from './operational-access.js';

export const EMERGENCY_MAINTENANCE_JOB = 'emergencias.revisar_plazos';
export const EMERGENCY_AGGREGATES_JOB = 'emergencias.recalcular_celdas';
export const EMERGENCY_ALERTS_JOB = 'emergencias.consultar_alertas';
export const EMERGENCY_ESCALATE_JOB = 'emergencias.escalar_pedido';
const warningJob = 'emergencias.avisar_plazo';
const noticeNamespace = '36f8212b-b3b1-5b0f-b91a-e51c0953102a';
const eventSchema = z.object({
  eventoId: z.uuid(),
  agregadoId: z.uuid(),
  carga: z.object({ zonaId: z.uuid(), usuarioId: z.uuid().optional() }),
});
const escalationSchema = z.strictObject({ pedidoId: z.uuid(), etapa: z.int().min(0).max(3) });

@Injectable()
export class EmergencyJobs implements OnModuleInit {
  constructor(
    private readonly registry: JobHandlerRegistry,
    @Inject(JOB_QUEUE) private readonly queue: JobQueue,
    @Inject(UNIT_OF_WORK) private readonly uow: UnitOfWork,
    @Inject(EVENT_STORE) private readonly events: EventStore,
    @Inject(REQUEST_STORE) private readonly requests: RequestStore,
    @Inject(OPERATIONS_STORE) private readonly operations: OperationsStore,
    @Inject(RESOURCE_STORE) private readonly resources: ResourceStore,
    @Inject(AUDIT_STORE) private readonly audit: AuditStore,
    @Inject(OUTBOX_WRITER) private readonly outbox: OutboxWriter,
    @Inject(OFFICIAL_ALERT_SOURCE) private readonly alerts: OfficialAlertSource,
    @Inject(CLOCK) private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    private readonly modes: ManageEvents,
    private readonly cases: ManageHelpRequests,
    private readonly access: OperationalAccess,
  ) {}
  onModuleInit(): void {
    this.registry.register(EMERGENCY_MAINTENANCE_JOB, () => this.maintain());
    this.registry.register(EMERGENCY_AGGREGATES_JOB, () =>
      this.uow.run((tx) => this.resources.refreshAggregates(tx, this.clock.now())),
    );
    this.registry.register(EMERGENCY_ALERTS_JOB, () => this.pollAlerts());
    this.registry.register(EMERGENCY_ESCALATE_JOB, async (data) => {
      const job = escalationSchema.parse(data);
      await this.escalate(job.pedidoId, job.etapa);
    });
    this.registry.register(warningJob, async (data) => {
      const job = escalationSchema.parse(data);
      await this.warn(job.pedidoId, job.etapa);
    });
    this.registry.register('emergencias.pedido_creado', (data) =>
      this.onRequest(data, 'caso_asignado'),
    );
    this.registry.register('emergencias.pedido_asignado', (data) =>
      this.onRequest(data, 'caso_asignado'),
    );
    this.registry.register('emergencias.pedido_escalado', (data) =>
      this.onRequest(data, 'pedido_escalado'),
    );
    this.registry.register('emergencias.pedido_actualizado', (data) => this.onRequest(data));
    this.registry.register('emergencias.evento_en_cierre', async (data) => {
      await this.closeBatch(eventSchema.parse(data).agregadoId);
    });
    // B acknowledges its completion fact; A observes it through a named subscriber.
    this.registry.register('emergencias.evento_cerrado', async (data) => {
      eventSchema.parse(data);
    });
    // The public zone notice of `emergencias.evento_activado` belongs to Notifications (Lot C).
  }
  private async onRequest(data: unknown, urgent?: UrgentTemplate): Promise<void> {
    const event = eventSchema.parse(data);
    const current = await this.uow.run(async (tx) => {
      const request = await this.requests.find(tx, event.agregadoId);
      if (!request || request.anonymizedAt) return null;
      const assigned = await this.requests.assignments(tx, request.id, this.clock.now());
      return {
        request,
        recipient:
          event.carga.usuarioId && assigned.some((item) => item.userId === event.carga.usuarioId)
            ? event.carga.usuarioId
            : null,
      };
    });
    if (!current) return;
    const { request, recipient } = current;
    if (request.state === 'enviado' && request.escalateAt) {
      await this.queue.enqueue(
        EMERGENCY_ESCALATE_JOB,
        { pedidoId: request.id, etapa: request.escalationStage },
        {
          priority: 'critical',
          singletonKey: `${request.id}:${request.escalationStage}:${request.escalateAt.toISOString()}`,
          delaySeconds: Math.max(
            0,
            Math.ceil((request.escalateAt.getTime() - this.clock.now().getTime()) / 1000),
          ),
        },
      );
    }
    if (request.state === 'enviado' && request.escalateAt) {
      await this.queue.enqueue(
        warningJob,
        { pedidoId: request.id, etapa: request.escalationStage },
        {
          priority: 'critical',
          singletonKey: `${request.id}:${request.escalationStage}:${request.escalateAt.toISOString()}:aviso`,
          delaySeconds: Math.max(
            0,
            Math.ceil((request.escalateAt.getTime() - this.clock.now().getTime()) / 1000) - 60,
          ),
        },
      );
    }
    if (recipient && urgent && request.closedAt === null) {
      const id = uuidv5(`${event.eventoId}:${recipient}`, noticeNamespace);
      await this.notifyOperator(id, recipient, request.id, urgent);
    }
    if (request.ownerId)
      await this.sendPersonal(
        uuidv5(`${event.eventoId}:propietario`, noticeNamespace),
        request.ownerId,
        request.id,
        urgent === 'pedido_escalado',
      );
  }
  private async notifyOperator(
    id: string,
    userId: string,
    requestId: string,
    template: UrgentTemplate,
  ): Promise<void> {
    if (this.config.EMERGENCY_URGENT_NOTICES_ENABLED) {
      await this.queue.enqueue(
        URGENT_NOTICE_JOB,
        { avisoId: id, usuarioId: userId, plantilla: template, datos: { casoId: requestId } },
        { priority: 'critical', singletonKey: id },
      );
    } else await this.sendPersonal(id, userId, requestId, false);
  }
  private async warn(id: string, stage: number): Promise<void> {
    const recipients = await this.uow.run(async (tx) => {
      const request = await this.requests.find(tx, id);
      const now = this.clock.now();
      if (
        !request ||
        request.state !== 'enviado' ||
        request.escalationStage !== stage ||
        !request.escalateAt ||
        request.escalateAt <= now ||
        request.escalateAt.getTime() - now.getTime() > 60000
      )
        return [];
      const event = await this.events.find(tx, request.eventId);
      if (!event || event.state !== 'emergencia') return [];
      return (await this.requests.assignments(tx, id, now))
        .filter((item) => item.role === 'coordinador')
        .map((item) => item.userId);
    });
    for (const userId of recipients)
      await this.notifyOperator(
        uuidv5(`${id}:${stage}:${userId}:plazo`, noticeNamespace),
        userId,
        id,
        'pedido_por_escalar',
      );
  }
  private sendPersonal(
    id: string,
    userId: string,
    requestId: string,
    alternatives: boolean,
  ): Promise<void> {
    return this.queue.enqueue(
      SEND_NOTIFICATION_JOB,
      {
        avisoId: id,
        destino: { tipo: 'usuario', usuarioId: userId },
        plantilla: 'pedido_actualizado',
        datos: {
          pedidoId: requestId,
          ...(alternatives ? { alternativas: 'directorio_emergencia' } : {}),
        },
      },
      { priority: 'critical', singletonKey: id },
    );
  }
  async escalate(id: string, expectedStage?: number): Promise<void> {
    await this.uow.run(async (tx) => {
      const request = await this.requests.find(tx, id);
      const now = this.clock.now();
      if (
        !request ||
        request.state !== 'enviado' ||
        !request.escalateAt ||
        request.escalateAt > now ||
        request.expiresAt <= now ||
        (expectedStage !== undefined && expectedStage !== request.escalationStage)
      )
        return;
      await this.events.lockZone(tx, request.zoneId);
      const event = await this.events.find(tx, request.eventId);
      if (!event || event.state !== 'emergencia') return;
      const zones = [request.zoneId, ...(await this.operations.supportZones(tx, request.zoneId))];
      const assigned = await this.requests.assignments(tx, id, now);
      let selected: Awaited<ReturnType<OperationalAccess['eligible']>>[number] | undefined;
      for (const zone of zones) {
        for (const person of await this.access.eligible(tx, zone, 'coordinador')) {
          if (
            person.shift &&
            person.id !== request.ownerId &&
            !assigned.some((item) => item.userId === person.id) &&
            !(await this.requests.wasEscalatedTo(tx, id, person.id))
          ) {
            selected = person;
            break;
          }
        }
        if (selected) break;
      }
      const stage = request.escalationStage + 1;
      const updated: HelpRequest = {
        ...request,
        version: request.version + 1,
        escalationStage: stage,
        escalateAt:
          stage < 3
            ? new Date(
                Math.min(
                  request.expiresAt.getTime(),
                  now.getTime() + this.cases.reviewSeconds(request.priority) * 1000,
                ),
              )
            : null,
      };
      if (selected)
        await this.requests.assign(
          tx,
          {
            id: newId(),
            requestId: id,
            userId: selected.id,
            role: 'coordinador',
            expiresAt: this.access.assignmentExpiry(selected, request.expiresAt),
          },
          now,
        );
      await this.requests.recordEscalation(tx, updated, selected?.id ?? null, now);
      await this.requests.update(tx, updated);
      await this.requests.addHistory(
        tx,
        id,
        {
          from: 'enviado',
          to: 'enviado',
          role: 'sistema',
          at: now,
          reason: 'Plazo de primera revisión vencido',
        },
        null,
      );
      await this.audit.record(tx, null, 'sistema', id, 'pedido_escalado', now);
      await this.outbox.record(tx, 'emergencias', [
        {
          type: 'emergencias.pedido_escalado',
          aggregateId: id,
          occurredAt: now,
          payload: { zonaId: request.zoneId, ...(selected ? { usuarioId: selected.id } : {}) },
        },
      ]);
    });
  }
  async maintain(): Promise<void> {
    const batch = await this.uow.run(async (tx) => {
      const now = this.clock.now();
      await this.operations.expireAssignments(tx, now);
      return {
        due: await this.requests.due(tx, now),
        expired: await this.requests.expired(tx, now),
        closing: await this.events.closing(tx),
      };
    });
    for (const id of batch.expired) await this.expire(id);
    for (const id of batch.due) await this.escalate(id);
    for (const id of batch.closing) await this.closeBatch(id);
  }
  private async expire(id: string): Promise<void> {
    await this.uow.run(async (tx) => {
      const request = await this.requests.find(tx, id);
      const now = this.clock.now();
      if (!request || request.expiresAt > now) return;
      if (request.closedAt) {
        await this.requests.removePrivate(tx, id);
        return;
      }
      const updated: HelpRequest = {
        ...request,
        state: 'cerrado_sin_atender',
        closedAt: now,
        escalateAt: null,
        version: request.version + 1,
      };
      await this.requests.update(tx, updated);
      await this.requests.removePrivate(tx, id);
      await this.requests.addHistory(
        tx,
        id,
        {
          from: request.state,
          to: 'cerrado_sin_atender',
          role: 'sistema',
          at: now,
          reason: 'Plazo de conservación vencido',
        },
        null,
      );
      await this.audit.record(tx, null, 'sistema', id, 'pedido_caducado', now);
      await this.outbox.record(tx, 'emergencias', [
        {
          type: 'emergencias.pedido_actualizado',
          aggregateId: id,
          occurredAt: now,
          payload: { zonaId: request.zoneId },
        },
      ]);
    });
  }
  async closeBatch(id: string): Promise<void> {
    for (let attempt = 0; attempt < 10; attempt++) {
      const done = await this.uow.run(async (tx) => {
        let event = await this.events.find(tx, id);
        if (!event) return true;
        await this.events.lockZone(tx, event.zoneId);
        event = await this.events.find(tx, id);
        if (!event || event.state !== 'recuperacion') return true;
        const now = this.clock.now();
        const completed = await this.events.anonymizeBatch(tx, id, now);
        if (completed) {
          await this.resources.refreshAggregates(tx, now);
          await this.outbox.record(tx, 'emergencias', [
            {
              type: 'emergencias.evento_cerrado',
              aggregateId: id,
              occurredAt: now,
              payload: { zonaId: event.zoneId },
            },
          ]);
        }
        return completed;
      });
      if (done) return;
    }
    // A bounded job yields; the maintenance schedule picks up any remaining batches.
  }
  async pollAlerts(): Promise<void> {
    if (!this.config.EMERGENCIES_ENABLED) return;
    for (const alert of await this.alerts.read()) await this.modes.ingest(alert);
  }
}
