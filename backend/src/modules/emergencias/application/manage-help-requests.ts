import { createHash } from 'node:crypto';
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
import {
  assertVersion,
  isOpen,
  publicCell,
  transition,
  type Coordinates,
  type HelpRequest,
  type Need,
  type Priority,
  type RequestState,
} from '../domain/emergency.js';
import {
  AUDIT_STORE,
  type AuditStore,
  EVENT_STORE,
  type EventStore,
  OPERATIONS_STORE,
  type OperationsStore,
  REQUEST_STORE,
  type RequestStore,
  type StreamAccess,
} from './ports.js';
import { ManageEvents } from './manage-events.js';
import { OperationalAccess } from './operational-access.js';

export interface NewHelpRequest {
  readonly id: string;
  readonly eventId: string;
  readonly need: Need;
  readonly priority: Priority;
  readonly description: string;
  readonly location: Coordinates;
  readonly lifeThreatening: boolean;
}

@Injectable()
export class ManageHelpRequests {
  constructor(
    @Inject(UNIT_OF_WORK) private readonly uow: UnitOfWork,
    @Inject(REQUEST_STORE) private readonly requests: RequestStore,
    @Inject(EVENT_STORE) private readonly events: EventStore,
    @Inject(OPERATIONS_STORE) private readonly operations: OperationsStore,
    @Inject(AUDIT_STORE) private readonly audit: AuditStore,
    @Inject(OUTBOX_WRITER) private readonly outbox: OutboxWriter,
    @Inject(OPERATIONAL_IDENTITY) private readonly identity: OperationalIdentity,
    @Inject(CLOCK) private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    private readonly access: OperationalAccess,
    private readonly modes: ManageEvents,
    private readonly accounts: AccountAccess,
  ) {}
  reviewSeconds(priority: Priority): number {
    return priority === 'alta'
      ? this.config.EMERGENCY_REVIEW_HIGH_SECONDS
      : priority === 'media'
        ? this.config.EMERGENCY_REVIEW_MEDIUM_SECONDS
        : this.config.EMERGENCY_REVIEW_LOW_SECONDS;
  }
  async create(input: NewHelpRequest, actor: Actor): Promise<HelpRequest> {
    this.modes.requireEnabled();
    if (input.lifeThreatening)
      throw new BusinessRuleViolation(
        'riesgo_vital',
        'El riesgo para la vida requiere contactar directamente a los servicios oficiales.',
        'conflict',
        { accionAlternativa: 'directorio_emergencia' },
      );
    const fingerprint = createHash('sha256')
      .update(
        JSON.stringify([
          input.eventId,
          input.need,
          input.priority,
          input.description,
          input.location.lat,
          input.location.lng,
        ]),
      )
      .digest('hex');
    return this.uow.run(async (tx) => {
      await this.accounts.requireActiveWrite(tx, actor.id);
      const existing = await this.requests.find(tx, input.id);
      if (existing) {
        if (existing.ownerId !== actor.id) throw new ResourceNotFound('el pedido', input.id);
        if (existing.fingerprint !== fingerprint)
          throw new BusinessRuleViolation(
            'id_en_uso',
            'Ese identificador ya corresponde a otro pedido.',
            'conflict',
          );
        return existing;
      }
      let event = await this.events.find(tx, input.eventId);
      if (!event) throw new ResourceNotFound('el evento', input.eventId);
      this.access.requireZone(actor, event.zoneId);
      await this.events.lockZone(tx, event.zoneId);
      event = await this.events.find(tx, input.eventId);
      if (!event) throw new ResourceNotFound('el evento', input.eventId);
      if (event.state !== 'emergencia')
        throw new BusinessRuleViolation(
          'evento_no_activo',
          'El evento ya no admite pedidos.',
          'conflict',
        );
      const coordinators = (await this.access.requireCoverage(tx, event.zoneId)).filter(
        (person) => person.id !== actor.id,
      );
      if (!coordinators.length)
        throw new BusinessRuleViolation(
          'zona_sin_cobertura',
          'No hay otra persona de coordinación disponible. Consulta el directorio de emergencia.',
          'conflict',
          { accionAlternativa: 'directorio_emergencia' },
        );
      if (!(await this.identity.contains(tx, event.zoneId, input.location.lat, input.location.lng)))
        throw new BusinessRuleViolation(
          'ubicacion_fuera_de_zona',
          'La ubicación debe estar dentro de la zona seleccionada.',
        );
      const now = this.clock.now();
      const expiresAt = new Date(now.getTime() + this.config.EMERGENCY_REQUEST_TTL_SECONDS * 1000);
      const request: HelpRequest = {
        id: input.id,
        eventId: event.id,
        zoneId: event.zoneId,
        ownerId: actor.id,
        need: input.need,
        priority: input.priority,
        state: 'enviado',
        version: 1,
        cell: publicCell(input.location),
        createdAt: now,
        expiresAt,
        seenAt: null,
        closedAt: null,
        escalateAt: new Date(now.getTime() + this.reviewSeconds(input.priority) * 1000),
        escalationStage: 0,
        fingerprint,
        anonymizedAt: null,
      };
      await this.requests.insert(tx, request, {
        description: input.description,
        location: input.location,
      });
      // Deterministic rotation avoids sending every request to the first coordinator.
      const hash = createHash('sha256').update(input.id).digest().readUInt32BE(0);
      const coordinator = coordinators[hash % coordinators.length]!;
      await this.requests.assign(
        tx,
        {
          id: newId(),
          requestId: request.id,
          userId: coordinator.id,
          role: 'coordinador',
          expiresAt: this.access.assignmentExpiry(coordinator, expiresAt),
        },
        now,
      );
      await this.requests.recordEscalation(tx, request, coordinator.id, now);
      await this.requests.addHistory(
        tx,
        request.id,
        { from: null, to: 'enviado', role: 'vecino', at: now, reason: null },
        actor.id,
      );
      await this.audit.record(tx, actor.id, 'vecino', request.id, 'pedido_creado', now);
      await this.emit(tx, 'emergencias.pedido_creado', request, { usuarioId: coordinator.id });
      return request;
    });
  }
  async list(actor: Actor, page: { cursor?: string; limit: number }, zoneId?: string) {
    return this.uow.run(async (tx) => {
      if (zoneId) await this.access.require(tx, actor, zoneId, ['coordinador']);
      const requests = await this.requests.list(
        tx,
        zoneId
          ? { ...page, zoneId, operatorId: actor.id, now: this.clock.now() }
          : { ...page, ownerId: actor.id, now: this.clock.now() },
      );
      for (const request of requests)
        await this.audit.record(
          tx,
          actor.id,
          zoneId ? 'coordinador' : 'vecino',
          request.id,
          zoneId ? 'cola_consultada' : 'resumen_propio',
          this.clock.now(),
        );
      return Promise.all(
        requests.map(async (request) => ({
          ...request,
          assignments: zoneId
            ? await this.requests.assignments(tx, request.id, this.clock.now())
            : undefined,
        })),
      );
    });
  }
  async detail(id: string, actor: Actor) {
    return this.uow.run(async (tx) => {
      const request = await this.requireRequest(tx, id);
      const now = this.clock.now();
      const assignments = await this.requests.assignments(tx, id, now);
      const own = request.ownerId === actor.id;
      const assigned = assignments.find((item) => item.userId === actor.id);
      if (!own) {
        if (!assigned || !actor.zoneId || !isOpen(request.state))
          throw new ResourceNotFound('el pedido', id);
        await this.access.require(tx, actor, actor.zoneId, [assigned.role]);
        await this.requireSupport(tx, request.zoneId, actor.zoneId);
      }
      if (request.expiresAt <= now) throw new ResourceNotFound('el detalle vigente', id);
      await this.audit.record(
        tx,
        actor.id,
        own ? 'vecino' : assigned!.role,
        id,
        'detalle_consultado',
        now,
      );
      const details = await this.requests.details(tx, id);
      if ((own || request.state === 'en_camino') && details?.location) {
        await this.audit.record(
          tx,
          actor.id,
          own ? 'vecino' : assigned!.role,
          id,
          'ubicacion_exacta_consultada',
          now,
        );
      }
      return {
        request,
        description: details?.description ?? null,
        exactLocation: own || request.state === 'en_camino' ? (details?.location ?? null) : null,
        assignments: own ? [] : assignments,
        history: await this.requests.history(tx, id),
      };
    });
  }
  async change(
    id: string,
    expected: number,
    target: RequestState,
    reason: string | undefined,
    actor: Actor,
  ): Promise<HelpRequest> {
    return this.uow.run(async (tx) => {
      await this.accounts.requireActiveWrite(tx, actor.id);
      const request = await this.requireRequest(tx, id);
      const assignments = await this.requests.assignments(tx, id, this.clock.now());
      if (request.ownerId !== actor.id && !assignments.some((item) => item.userId === actor.id)) {
        throw new ResourceNotFound('el pedido', id);
      }
      let role: string;
      if (target === 'atendido') {
        if (request.ownerId !== actor.id)
          throw new BusinessRuleViolation(
            'confirmacion_del_vecino_requerida',
            'Solo quien pidió ayuda puede confirmar la atención.',
            'forbidden',
          );
        role = 'vecino';
      } else {
        const required = target === 'en_camino' ? 'brigadista' : 'coordinador';
        if (
          !actor.zoneId ||
          !assignments.some((item) => item.userId === actor.id && item.role === required)
        )
          throw new ResourceNotFound('el pedido', id);
        await this.access.require(tx, actor, actor.zoneId, [required]);
        role = required;
        await this.requireSupport(tx, request.zoneId, actor.zoneId);
      }
      assertVersion(expected, request.version);
      await this.requireActiveEvent(tx, request);
      transition(request, target, reason);
      const now = this.clock.now();
      const updated: HelpRequest = {
        ...request,
        state: target,
        version: request.version + 1,
        seenAt: target === 'visto' ? now : request.seenAt,
        escalateAt: null,
        closedAt: isOpen(target) ? null : now,
      };
      await this.requests.update(tx, updated);
      await this.requests.addHistory(
        tx,
        id,
        { from: request.state, to: target, role, at: now, reason: reason?.trim() ?? null },
        actor.id,
      );
      await this.audit.record(tx, actor.id, role, id, 'estado_actualizado', now);
      await this.emit(tx, 'emergencias.pedido_actualizado', updated, {});
      return updated;
    });
  }
  async assign(
    id: string,
    expected: number,
    userId: string,
    actor: Actor,
    role: 'coordinador' | 'brigadista' = 'brigadista',
  ): Promise<HelpRequest> {
    return this.uow.run(async (tx) => {
      await this.accounts.requireActiveWrite(tx, actor.id);
      const request = await this.requireRequest(tx, id);
      if (!actor.zoneId) throw new ResourceNotFound('el pedido', id);
      await this.access.require(tx, actor, actor.zoneId, ['coordinador']);
      if (
        actor.zoneId !== request.zoneId &&
        !(await this.requests.assignments(tx, id, this.clock.now())).some(
          (item) => item.userId === actor.id && item.role === 'coordinador',
        )
      ) {
        throw new ResourceNotFound('el pedido', id);
      }
      await this.requireSupport(tx, request.zoneId, actor.zoneId);
      assertVersion(expected, request.version);
      await this.requireActiveEvent(tx, request);
      if (role === 'coordinador' && userId !== actor.id)
        throw new BusinessRuleViolation(
          'asignacion_invalida',
          'Un coordinador solo puede tomar el caso para sí mismo.',
          'forbidden',
        );
      if (
        (role === 'brigadista' && request.state !== 'visto') ||
        (role === 'coordinador' && !['enviado', 'visto'].includes(request.state))
      ) {
        throw new BusinessRuleViolation(
          'transicion_invalida',
          'Revisa el pedido antes de asignarlo; un caso en camino no admite esta reasignación.',
          'conflict',
        );
      }
      const candidate = (await this.access.eligible(tx, actor.zoneId, role)).find(
        (item) => item.id === userId && item.shift !== null,
      );
      if (!candidate)
        throw new BusinessRuleViolation(
          'persona_no_disponible',
          'La persona debe tener habilitación y estar de turno.',
          'conflict',
        );
      if (candidate.id === request.ownerId)
        throw new BusinessRuleViolation(
          'asignacion_invalida',
          'El pedido debe atenderlo otra persona.',
        );
      const now = this.clock.now();
      await this.requests.assign(
        tx,
        {
          id: newId(),
          requestId: id,
          userId,
          role,
          expiresAt: this.access.assignmentExpiry(candidate, request.expiresAt),
        },
        now,
      );
      const updated = { ...request, version: request.version + 1 };
      await this.requests.update(tx, updated);
      await this.audit.record(tx, actor.id, 'coordinador', id, 'asignacion_actualizada', now);
      await this.emit(tx, 'emergencias.pedido_asignado', updated, { usuarioId: userId });
      return updated;
    });
  }
  async prioritize(
    id: string,
    expected: number,
    priority: Priority,
    reason: string,
    actor: Actor,
  ): Promise<HelpRequest> {
    return this.uow.run(async (tx) => {
      await this.accounts.requireActiveWrite(tx, actor.id);
      const request = await this.requireRequest(tx, id);
      if (
        !actor.zoneId ||
        !(await this.requests.assignments(tx, id, this.clock.now())).some(
          (item) => item.userId === actor.id && item.role === 'coordinador',
        )
      ) {
        throw new ResourceNotFound('el pedido', id);
      }
      await this.access.require(tx, actor, actor.zoneId, ['coordinador']);
      await this.requireSupport(tx, request.zoneId, actor.zoneId);
      assertVersion(expected, request.version);
      await this.requireActiveEvent(tx, request);
      if (!isOpen(request.state))
        throw new BusinessRuleViolation(
          'transicion_invalida',
          'El pedido ya está cerrado.',
          'conflict',
        );
      const now = this.clock.now();
      const updated: HelpRequest = {
        ...request,
        priority,
        version: request.version + 1,
        escalateAt:
          request.state === 'enviado'
            ? new Date(
                Math.min(
                  request.expiresAt.getTime(),
                  request.createdAt.getTime() + this.reviewSeconds(priority) * 1000,
                ),
              )
            : null,
      };
      await this.requests.update(tx, updated);
      await this.requests.addHistory(
        tx,
        id,
        { from: request.state, to: request.state, role: 'coordinador', at: now, reason },
        actor.id,
      );
      await this.audit.record(tx, actor.id, 'coordinador', id, 'prioridad_actualizada', now);
      await this.emit(tx, 'emergencias.pedido_actualizado', updated, {});
      return updated;
    });
  }
  /**
   * Audited opening of a case on the assigned operator's phone (Lot A, part 2). The permission is
   * tied to the assignment, the session and the scope: the summary while the case is open, the
   * exact location only while it is «En camino». It ends with the assignment.
   */
  async openSyncAccess(
    id: string,
    scope: StreamAccess['scope'],
    actor: Actor,
  ): Promise<StreamAccess> {
    const sessionId = actor.sessionId;
    if (!sessionId)
      throw new BusinessRuleViolation(
        'sesion_requerida',
        'Vuelve a iniciar sesión en el celular para abrir el caso.',
        'forbidden',
      );
    return this.uow.run(async (tx) => {
      await this.accounts.requireActiveWrite(tx, actor.id);
      const request = await this.requireRequest(tx, id);
      const now = this.clock.now();
      const assignment = (await this.requests.assignments(tx, id, now)).find(
        (item) => item.userId === actor.id,
      );
      if (!assignment || !actor.zoneId || !isOpen(request.state) || request.expiresAt <= now)
        throw new ResourceNotFound('el pedido', id);
      await this.access.require(tx, actor, actor.zoneId, [assignment.role]);
      await this.requireSupport(tx, request.zoneId, actor.zoneId);
      if (scope === 'exacta' && request.state !== 'en_camino')
        throw new BusinessRuleViolation(
          'ubicacion_no_disponible',
          'La ubicación exacta se abre cuando el caso está en camino.',
          'conflict',
        );
      const access = await this.requests.openStreamAccess(tx, {
        id: newId(),
        assignmentId: assignment.id,
        requestId: id,
        userId: actor.id,
        sessionId,
        scope,
        createdAt: now,
        expiresAt: assignment.expiresAt,
      });
      await this.audit.record(
        tx,
        actor.id,
        assignment.role,
        id,
        scope === 'exacta' ? 'ubicacion_exacta_autorizada' : 'caso_abierto_en_celular',
        now,
      );
      return access;
    });
  }
  async requireRequest(tx: TransactionContext, id: string): Promise<HelpRequest> {
    const request = await this.requests.find(tx, id);
    if (!request || request.anonymizedAt) throw new ResourceNotFound('el pedido', id);
    return request;
  }
  private async requireSupport(
    tx: TransactionContext,
    sourceZone: string,
    operatorZone: string,
  ): Promise<void> {
    if (
      sourceZone !== operatorZone &&
      !(await this.operations.supportZones(tx, sourceZone)).includes(operatorZone)
    ) {
      throw new BusinessRuleViolation(
        'zona_sin_acuerdo',
        'La zona de apoyo ya no está autorizada.',
        'forbidden',
      );
    }
  }
  private async requireActiveEvent(tx: TransactionContext, request: HelpRequest): Promise<void> {
    this.modes.requireEnabled();
    await this.events.lockZone(tx, request.zoneId);
    const event = await this.events.find(tx, request.eventId);
    if (!event || event.state !== 'emergencia' || request.expiresAt <= this.clock.now())
      throw new BusinessRuleViolation(
        'pedido_no_vigente',
        'El pedido ya no admite cambios.',
        'conflict',
      );
  }
  private emit(
    tx: TransactionContext,
    type: string,
    request: HelpRequest,
    extra: Readonly<Record<string, string>>,
  ): Promise<void> {
    return this.outbox.record(tx, 'emergencias', [
      {
        type,
        aggregateId: request.id,
        occurredAt: this.clock.now(),
        payload: { zonaId: request.zoneId, ...extra },
      },
    ]);
  }
}
