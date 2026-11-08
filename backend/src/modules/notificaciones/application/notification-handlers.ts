import { Inject, Injectable, type OnModuleInit } from '@nestjs/common';
import { v5 as uuidv5 } from 'uuid';
import { z } from 'zod';
import { JobHandlerRegistry } from '../../../shared/queues/job-handler.registry.js';
import { JOB_QUEUE, type JobQueue } from '../../../shared/queues/job-queue.js';
import {
  NOTIFICATION_PORT,
  NOTIFICATION_DELIVERY,
  type NotificationPort,
  type NotificationDelivery,
} from './ports.js';
import { SEND_NOTIFICATION_JOB } from './send-notification.job.js';
import {
  emergencyActivatedMessage,
  favorTakenMessage,
  requestUpdatedMessage,
  zoneNoticeMessage,
} from '../domain/templates.js';

const id = z.uuid();
const sendJobSchema = z.union([
  z.strictObject({
    avisoId: id,
    destino: z.strictObject({ tipo: z.literal('usuario'), usuarioId: id }),
    plantilla: z.literal('pedido_actualizado'),
    datos: z.strictObject({
      pedidoId: id,
      alternativas: z.literal('directorio_emergencia').optional(),
    }),
  }),
  z.strictObject({
    avisoId: id,
    destino: z.strictObject({ tipo: z.literal('usuario'), usuarioId: id }),
    plantilla: z.literal('favor_tomado'),
    datos: z.strictObject({ publicacionId: id }),
  }),
  z.strictObject({
    avisoId: id,
    destino: z.strictObject({ tipo: z.literal('zona'), zonaId: id }),
    plantilla: z.literal('aviso_de_zona'),
    datos: z.strictObject({}),
  }),
  z.strictObject({
    avisoId: id,
    destino: z.strictObject({ tipo: z.literal('zona'), zonaId: id }),
    plantilla: z.literal('modo_emergencia_activado'),
    datos: z.strictObject({}),
  }),
]);
const eventSchema = z.object({ eventoId: id, agregadoId: id, carga: z.object({ autorId: id }) });
/** Emitted by Emergencies (Phase 2, Lot B) when a zone enters emergency mode. */
export const EMERGENCY_ACTIVATED_EVENT = 'emergencias.evento_activado';
const emergencyActivatedSchema = z.object({ eventoId: id, carga: z.object({ zonaId: id }) });
// Fixed namespace: changing it would change the idempotency identity of replayed events.
const NOTICE_NAMESPACE = '2c575aef-177d-5b7f-88da-f029623dc084';

@Injectable()
export class NotificationHandlers implements OnModuleInit {
  constructor(
    private readonly registry: JobHandlerRegistry,
    @Inject(JOB_QUEUE) private readonly queue: JobQueue,
    @Inject(NOTIFICATION_DELIVERY) private readonly deliveries: NotificationDelivery,
    @Inject(NOTIFICATION_PORT) private readonly push: NotificationPort,
  ) {}

  onModuleInit(): void {
    this.registry.register('solidaridad.favor_tomado', (data) => this.favorTaken(data));
    this.registry.register(SEND_NOTIFICATION_JOB, (data) => this.send(data));
    this.registry.register(EMERGENCY_ACTIVATED_EVENT, (data) => this.emergencyActivated(data));
  }

  async favorTaken(data: unknown): Promise<void> {
    const event = eventSchema.parse(data);
    const avisoId = uuidv5(`${event.eventoId}:${event.carga.autorId}`, NOTICE_NAMESPACE);
    await this.queue.enqueue(
      SEND_NOTIFICATION_JOB,
      {
        avisoId,
        destino: { tipo: 'usuario', usuarioId: event.carga.autorId },
        plantilla: 'favor_tomado',
        datos: { publicacionId: event.agregadoId },
      },
      { singletonKey: avisoId, retries: 5 },
    );
  }

  /** Public zone notice (section 7.5): one per event and zone, even if the event is replayed. */
  async emergencyActivated(data: unknown): Promise<void> {
    const event = emergencyActivatedSchema.parse(data);
    const zonaId = event.carga.zonaId;
    const avisoId = uuidv5(`${event.eventoId}:zona:${zonaId}`, NOTICE_NAMESPACE);
    await this.queue.enqueue(
      SEND_NOTIFICATION_JOB,
      {
        avisoId,
        destino: { tipo: 'zona', zonaId },
        plantilla: 'modo_emergencia_activado',
        datos: {},
      },
      { singletonKey: avisoId, retries: 5, priority: 'critical' },
    );
  }

  async send(data: unknown): Promise<void> {
    const job = sendJobSchema.parse(data);
    const message =
      job.plantilla === 'favor_tomado'
        ? favorTakenMessage(job.datos.publicacionId)
        : job.plantilla === 'pedido_actualizado'
          ? requestUpdatedMessage(job.datos.pedidoId, job.datos.alternativas !== undefined)
          : job.plantilla === 'aviso_de_zona'
            ? zoneNoticeMessage(job.destino.zonaId)
            : emergencyActivatedMessage(job.destino.zonaId);
    await this.deliveries.deliver(job, message, this.push);
  }
}
