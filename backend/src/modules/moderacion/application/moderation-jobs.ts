import { Inject, Injectable, type OnModuleInit } from '@nestjs/common';
import { z } from 'zod';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import {
  CONTENT_APPROVED,
  CONTENT_HIDDEN,
  CONTENT_RESTORED,
  CONTENT_TYPES,
  ContentModerationRegistry,
  type ContentRef,
  type ContentType,
  type VisibilityEvent,
} from '../../../shared/moderation/content-moderation.js';
import { JobHandlerRegistry } from '../../../shared/queues/job-handler.registry.js';
import { REPORT_REASONS } from '../domain/moderation.js';
import { ModerationEvents, REPORT_CREATED } from './moderation-events.js';
import { MODERATION_STORE, type ModerationStore } from './ports.js';
import { ScreenContent } from './screen-content.js';

const aggregate = z.object({ agregadoId: z.uuid() });
const visibilityEnvelope = aggregate
  .extend({
    ocurridoEn: z.iso.datetime(),
    carga: z.object({
      tipoContenido: z.enum(CONTENT_TYPES),
      contenidoId: z.uuid(),
      motivo: z.string(),
    }),
  })
  .refine((event) => event.agregadoId === event.carga.contenidoId);

function minimumTrust(type: ContentType): number {
  return type === 'resena' || type === 'foto' ? 2 : 1;
}

const newContent = {
  'solidaridad.publicacion_creada': 'publicacion',
  'directorio.servicio_publicado': 'servicio',
  'directorio.proveedor_publicado': 'proveedor',
  'reputacion.resena_creada': 'resena',
} as const satisfies Record<string, ContentType>;

@Injectable()
export class ModerationJobs implements OnModuleInit {
  constructor(
    private readonly jobs: JobHandlerRegistry,
    @Inject(UNIT_OF_WORK) private readonly unitOfWork: UnitOfWork,
    @Inject(CLOCK) private readonly clock: Clock,
    @Inject(MODERATION_STORE) private readonly store: ModerationStore,
    private readonly content: ContentModerationRegistry,
    private readonly screen: ScreenContent,
    private readonly events: ModerationEvents,
  ) {}

  onModuleInit(): void {
    for (const [name, type] of Object.entries(newContent)) {
      this.jobs.register(name, (data) =>
        this.screenNew({ type, id: aggregate.parse(data).agregadoId }),
      );
    }
    this.jobs.register(REPORT_CREATED, (data) =>
      this.screenReport(aggregate.parse(data).agregadoId),
    );
    for (const name of [CONTENT_APPROVED, CONTENT_HIDDEN, CONTENT_RESTORED] as const) {
      this.jobs.register(name, (data) => this.apply(name, data));
    }
  }

  screenNew(ref: ContentRef): Promise<void> {
    return this.unitOfWork.run(async (tx) => {
      await this.store.lockContent(tx, ref);
      const pending = await this.store.caseForContent(tx, ref);
      if ((await this.store.visibility(tx, ref)) || pending?.state === 'resuelto') return;
      // A report already waiting for a human must never be bypassed by an automatic approval.
      if (pending && !(REPORT_REASONS as readonly string[]).includes(pending.reason)) return;
      const target = await this.content.owner(ref.type).read(tx, ref);
      if (!target) return;
      const now = this.clock.now();
      const flag = await this.screen.evaluate(tx, target, now, undefined, minimumTrust(ref.type));
      if (flag) {
        if (!pending) await this.store.openCase(tx, ref, target.ownerId, flag, now, false);
        // Reviews already start hidden from the public while awaiting a verdict.
        if (ref.type !== 'resena')
          await this.events.visibility(tx, ref, CONTENT_HIDDEN, 'revision_pendiente', now);
      } else if (!pending) {
        await this.events.visibility(tx, ref, CONTENT_APPROVED, 'aprobado', now);
      }
    });
  }

  screenReport(id: string): Promise<void> {
    return this.unitOfWork.run(async (tx) => {
      await this.store.lockReport(tx, id);
      const report = await this.store.findReport(tx, id);
      if (!report) return;
      const target = await this.content.owner(report.content.type).read(tx, report.content);
      if (!target) return;
      // A report always stays in the human queue, even when the automated checks find nothing.
      const flag = await this.screen.evaluate(
        tx,
        target,
        this.clock.now(),
        report.details ?? undefined,
        minimumTrust(report.content.type),
      );
      await this.store.markReportScreened(tx, id, flag);
    });
  }

  private apply(event: VisibilityEvent, data: unknown): Promise<boolean> {
    const { carga, ocurridoEn } = visibilityEnvelope.parse(data);
    const ref = { type: carga.tipoContenido, id: carga.contenidoId };
    const at = new Date(ocurridoEn);
    return this.unitOfWork.run(async (tx) => {
      await this.store.lockContent(tx, ref);
      const current = await this.store.visibility(tx, ref);
      if (!current || current.event !== event || current.at.getTime() !== at.getTime())
        return false;
      // A subscriber may need a retry after the owner already applied the decision.
      if (current.appliedAt) return true;
      await this.content.owner(ref.type).apply(tx, ref, event, carga.motivo, at);
      await this.store.markVisibilityApplied(tx, ref, this.clock.now());
      return true;
    });
  }
}
