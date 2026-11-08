import { createHash } from 'node:crypto';
import { Inject, Injectable } from '@nestjs/common';
import type { Actor } from '../../../shared/auth/actor.js';
import { AccountAccess } from '../../../shared/auth/account-access.js';
import { APP_CONFIG, type AppConfig } from '../../../shared/config/app-config.js';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { BusinessRuleViolation, ResourceNotFound } from '../../../shared/domain/errors.js';
import { OPERATIONAL_IDENTITY, type OperationalIdentity } from '../../identidad/index.js';
import {
  assertVersion,
  publicCell,
  type Coordinates,
  type CriticalResource,
  type ResourceType,
} from '../domain/emergency.js';
import { AUDIT_STORE, type AuditStore, RESOURCE_STORE, type ResourceStore } from './ports.js';
import { ManageEvents } from './manage-events.js';
import { OperationalAccess } from './operational-access.js';

@Injectable()
export class ManageResources {
  constructor(
    @Inject(UNIT_OF_WORK) private readonly uow: UnitOfWork,
    @Inject(RESOURCE_STORE) private readonly resources: ResourceStore,
    @Inject(AUDIT_STORE) private readonly audit: AuditStore,
    @Inject(OPERATIONAL_IDENTITY) private readonly identity: OperationalIdentity,
    @Inject(CLOCK) private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    private readonly access: OperationalAccess,
    private readonly accounts: AccountAccess,
    private readonly modes: ManageEvents,
  ) {}
  private staleSeconds(type: ResourceType): number {
    const values = {
      agua: this.config.EMERGENCY_WATER_STALE_SECONDS,
      alimentos: this.config.EMERGENCY_FOOD_STALE_SECONDS,
      medicamentos: this.config.EMERGENCY_MEDICINE_STALE_SECONDS,
      traslado: this.config.EMERGENCY_TRANSPORT_STALE_SECONDS,
      albergue: this.config.EMERGENCY_SHELTER_STALE_SECONDS,
      punto_encuentro: this.config.EMERGENCY_MEETING_POINT_STALE_SECONDS,
    };
    return values[type];
  }
  async report(
    input: {
      id: string;
      zoneId: string;
      type: ResourceType;
      quantity: number;
      location: Coordinates;
    },
    actor: Actor,
  ): Promise<CriticalResource> {
    this.modes.requireEnabled();
    this.access.requireZone(actor, input.zoneId);
    return this.uow.run(async (tx) => {
      await this.accounts.requireActiveWrite(tx, actor.id);
      const existing = await this.resources.find(tx, input.id);
      const cell = publicCell(input.location);
      const fingerprint = createHash('sha256')
        .update(JSON.stringify([input.zoneId, input.type, input.quantity, cell]))
        .digest('hex');
      if (existing) {
        if (existing.reporterId !== actor.id) throw new ResourceNotFound('el recurso', input.id);
        if (existing.creationFingerprint !== fingerprint)
          throw new BusinessRuleViolation(
            'id_en_uso',
            'Ese identificador corresponde a otro reporte.',
            'conflict',
          );
        return existing;
      }
      if (!(await this.identity.contains(tx, input.zoneId, input.location.lat, input.location.lng)))
        throw new BusinessRuleViolation(
          'ubicacion_fuera_de_zona',
          'La ubicación debe estar dentro de tu zona.',
        );
      const resource: CriticalResource = {
        id: input.id,
        zoneId: input.zoneId,
        reporterId: actor.id,
        creationFingerprint: fingerprint,
        type: input.type,
        quantity: input.quantity,
        cell,
        reportedAt: this.clock.now(),
        staleAfterSeconds: this.staleSeconds(input.type),
        verification: 'sin_verificar',
        confirmations: 0,
        publicLabel: null,
        sourceUrl: null,
        official: false,
        version: 1,
      };
      await this.resources.insert(tx, resource);
      return resource;
    });
  }
  async list(zoneId: string, actor: Actor, cursor: string | undefined, limit: number) {
    this.access.requireZone(actor, zoneId);
    return this.uow.run((tx) => this.resources.list(tx, zoneId, cursor, limit));
  }
  async update(
    id: string,
    expected: number,
    quantity: number,
    actor: Actor,
  ): Promise<CriticalResource> {
    this.modes.requireEnabled();
    return this.uow.run(async (tx) => {
      await this.accounts.requireActiveWrite(tx, actor.id);
      const resource = await this.resources.find(tx, id);
      if (!resource) throw new ResourceNotFound('el recurso', id);
      this.access.requireZone(actor, resource.zoneId);
      assertVersion(expected, resource.version);
      if (resource.reporterId !== actor.id)
        await this.access.require(tx, actor, resource.zoneId, ['coordinador', 'curador'], false);
      // A new quantity invalidates all evidence about the previous stock.
      const updated: CriticalResource = {
        ...resource,
        quantity,
        reportedAt: this.clock.now(),
        version: resource.version + 1,
        verification: 'sin_verificar',
        confirmations: 0,
        publicLabel: null,
        sourceUrl: null,
        official: false,
      };
      await this.resources.update(tx, updated, true);
      await this.audit.record(
        tx,
        actor.id,
        resource.reporterId === actor.id ? 'vecino' : 'operador',
        null,
        `recurso_actualizado:${id}`,
        this.clock.now(),
      );
      return updated;
    });
  }
  async confirm(id: string, expected: number, actor: Actor): Promise<CriticalResource> {
    this.modes.requireEnabled();
    return this.uow.run(async (tx) => {
      await this.accounts.requireActiveWrite(tx, actor.id);
      const resource = await this.resources.find(tx, id);
      if (!resource) throw new ResourceNotFound('el recurso', id);
      this.access.requireZone(actor, resource.zoneId);
      assertVersion(expected, resource.version);
      if (resource.reporterId === actor.id)
        throw new BusinessRuleViolation(
          'autoconfirmacion_no_permitida',
          'Tu propio reporte no cuenta como confirmación independiente.',
        );
      const now = this.clock.now();
      if (now.getTime() - resource.reportedAt.getTime() >= resource.staleAfterSeconds * 1000)
        throw new BusinessRuleViolation(
          'recurso_desactualizado',
          'Actualiza el reporte antes de confirmar su disponibilidad.',
          'conflict',
        );
      await this.resources.confirm(tx, id, actor.id, now);
      const confirmations = await this.resources.confirmationCount(tx, id);
      if (confirmations === resource.confirmations) return resource;
      const updated: CriticalResource = {
        ...resource,
        confirmations,
        version: resource.version + 1,
        verification: resource.verification === 'verificado' ? 'verificado' : 'confirmado',
      };
      await this.resources.update(tx, updated, false);
      return updated;
    });
  }
  async verify(
    id: string,
    expected: number,
    input: { label: string; sourceUrl?: string; official: boolean },
    actor: Actor,
  ): Promise<CriticalResource> {
    this.modes.requireEnabled();
    return this.uow.run(async (tx) => {
      await this.accounts.requireActiveWrite(tx, actor.id);
      const resource = await this.resources.find(tx, id);
      if (!resource) throw new ResourceNotFound('el recurso', id);
      assertVersion(expected, resource.version);
      if (input.official) {
        this.access.requireAdministrator(actor);
        if (!input.sourceUrl)
          throw new BusinessRuleViolation(
            'fuente_requerida',
            'Una fuente oficial necesita un enlace verificado.',
          );
      } else
        await this.access.require(tx, actor, resource.zoneId, ['coordinador', 'curador'], false);
      const updated: CriticalResource = {
        ...resource,
        publicLabel: input.label,
        sourceUrl: input.sourceUrl ?? null,
        official: input.official,
        verification: 'verificado',
        version: resource.version + 1,
      };
      await this.resources.update(tx, updated, false);
      await this.audit.record(
        tx,
        actor.id,
        input.official ? 'administrador' : 'operador',
        null,
        `recurso_verificado:${id}`,
        this.clock.now(),
      );
      return updated;
    });
  }
  async cells(zoneId: string, actor: Actor) {
    this.access.requireZone(actor, zoneId);
    return this.uow.run((tx) => this.resources.aggregates(tx, zoneId));
  }
}
