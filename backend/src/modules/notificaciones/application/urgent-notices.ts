import { Inject, Injectable } from '@nestjs/common';
import { createHash } from 'node:crypto';
import type { Actor } from '../../../shared/auth/actor.js';
import { APP_CONFIG, type AppConfig } from '../../../shared/config/app-config.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { ResourceNotFound, ValidationError } from '../../../shared/domain/errors.js';
import { JOB_QUEUE, type JobQueue } from '../../../shared/queues/job-queue.js';
import { CONTACT_DIRECTORY, type ContactDirectory } from '../../identidad/index.js';
import { URGENT_SMS_TEXT, urgentNoticeMessage } from '../domain/templates.js';
import {
  NOTIFICATION_DELIVERY,
  NOTIFICATION_PORT,
  SMS_PROVIDER,
  URGENT_NOTICES,
  type NotificationDelivery,
  type NotificationPort,
  type SmsProvider,
  type SmsResult,
  type UrgentNoticeStore,
} from './ports.js';
import { URGENT_REVIEW_JOB, type UrgentNoticeJob } from './urgent-notice.job.js';

/** Unconfirmed urgent notices older than this no longer show up as pending in the console. */
const PENDING_WINDOW_HOURS = 24;
const SUMMARY_DEFAULT_DAYS = 7;

export interface PendingUrgentNoticeDto {
  readonly id: string;
  readonly plantilla: string;
  readonly casoId: string | null;
  readonly creadoEn: string;
}

/**
 * Urgent notices never depend on a single channel (section 7.5): push to every device first and,
 * if nobody acknowledges within URGENT_ACK_TIMEOUT_SECONDS, an SMS within the spending caps.
 */
@Injectable()
export class UrgentNotices {
  constructor(
    @Inject(URGENT_NOTICES) private readonly store: UrgentNoticeStore,
    @Inject(NOTIFICATION_DELIVERY) private readonly deliveries: NotificationDelivery,
    @Inject(NOTIFICATION_PORT) private readonly push: NotificationPort,
    @Inject(SMS_PROVIDER) private readonly sms: SmsProvider,
    @Inject(CONTACT_DIRECTORY) private readonly contacts: ContactDirectory,
    @Inject(JOB_QUEUE) private readonly queue: JobQueue,
    @Inject(CLOCK) private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  async send(job: UrgentNoticeJob): Promise<void> {
    const now = this.clock.now();
    const casoId = job.datos.casoId ?? null;
    const fingerprint = createHash('sha256')
      .update(JSON.stringify([job.usuarioId, job.plantilla, casoId]))
      .digest('hex');
    const claim = await this.store.claim({
      avisoId: job.avisoId,
      usuarioId: job.usuarioId,
      plantilla: job.plantilla,
      casoId,
      fingerprint,
      confirmBefore: new Date(now.getTime() + this.config.URGENT_ACK_TIMEOUT_SECONDS * 1000),
    });
    if (claim === 'conflict') {
      throw new Error('El identificador del aviso urgente ya tiene otro contenido');
    }
    // The shared delivery is idempotent per device: a retried job resumes what is pending.
    await this.deliveries.deliver(
      {
        avisoId: job.avisoId,
        destino: { tipo: 'usuario', usuarioId: job.usuarioId },
        plantilla: `aviso_urgente:${job.plantilla}`,
      },
      urgentNoticeMessage(job.avisoId, job.datos.casoId),
      this.push,
    );
    const devices = await this.deliveries.deliveredCount(job.avisoId);
    await this.store.recordReach(job.avisoId, devices);
    // Without any device the token channel already failed: review now instead of waiting.
    await this.queue.enqueue(
      URGENT_REVIEW_JOB,
      { avisoId: job.avisoId },
      {
        singletonKey: job.avisoId,
        priority: 'critical',
        retries: 5,
        ...(devices > 0 ? { delaySeconds: this.config.URGENT_ACK_TIMEOUT_SECONDS } : {}),
      },
    );
  }

  async review(avisoId: string): Promise<void> {
    const notice = await this.store.find(avisoId);
    if (!notice) return;
    const providerEnabled = this.sms.name !== 'none';
    const phone =
      providerEnabled && !notice.confirmadoEn ? await this.contacts.phoneOf(notice.usuarioId) : null;
    const reservedAt = this.clock.now();
    const reservation = await this.store.reserveSms(
      avisoId,
      {
        now: reservedAt,
        costCents: this.config.SMS_COST_CENTS,
        dailyCapCents: this.config.SMS_DAILY_BUDGET_CENTS,
        monthlyCapCents: this.config.SMS_MONTHLY_BUDGET_CENTS,
      },
      { providerEnabled, hasPhone: phone !== null },
    );
    if (reservation.kind !== 'reserved' || phone === null) return;
    const reserved = { reservedAt, reservedCents: reservation.costCents };
    let result: SmsResult;
    try {
      result = await this.sms.send(phone, URGENT_SMS_TEXT);
    } catch (error) {
      await this.store.releaseSms(avisoId, reserved);
      throw error;
    }
    if (result.status === 'sent') {
      await this.store.markSmsSent(avisoId, this.clock.now(), {
        ...reserved,
        actualCents: result.costCents,
      });
      return;
    }
    await this.store.releaseSms(avisoId, reserved, result.retryable ? undefined : 'sms_fallido');
    // A retryable failure goes back to pg-boss, which retries the review with backoff.
    if (result.retryable) throw new Error('El proveedor de SMS no respondió; se reintentará');
  }

  async confirm(actor: Actor, avisoId: string): Promise<{ id: string; confirmadoEn: string }> {
    const confirmedAt = await this.store.confirm(avisoId, actor.id, this.clock.now());
    // Another person's notice answers exactly like a missing one: nothing to learn from it.
    if (!confirmedAt) throw new ResourceNotFound('aviso urgente', avisoId);
    return { id: avisoId, confirmadoEn: confirmedAt.toISOString() };
  }

  async pendingFor(actor: Actor): Promise<{ datos: PendingUrgentNoticeDto[] }> {
    const since = new Date(this.clock.now().getTime() - PENDING_WINDOW_HOURS * 3_600_000);
    const notices = await this.store.pendingFor(actor.id, since);
    return {
      datos: notices.map((notice) => ({
        id: notice.avisoId,
        plantilla: notice.plantilla,
        casoId: notice.casoId,
        creadoEn: notice.creadoEn.toISOString(),
      })),
    };
  }

  async summary(desde?: Date) {
    const now = this.clock.now();
    const since = desde ?? new Date(now.getTime() - SUMMARY_DEFAULT_DAYS * 86_400_000);
    if (since.getTime() > now.getTime()) {
      throw new ValidationError([{ field: 'desde', message: 'No puede estar en el futuro.' }]);
    }
    const summary = await this.store.summary(since, now, now);
    return {
      desde: since.toISOString(),
      hasta: now.toISOString(),
      proveedorSms: this.sms.name,
      total: summary.total,
      confirmados: summary.confirmados,
      sinConfirmar: summary.sinConfirmar,
      smsEnviados: summary.smsEnviados,
      sinRespaldo: summary.sinRespaldo,
      confirmacionSegundos: summary.confirmacionSegundos,
      gasto: {
        moneda: 'USD',
        hoyCentavos: summary.gasto.hoyCentavos,
        mesCentavos: summary.gasto.mesCentavos,
        topeDiarioCentavos: this.config.SMS_DAILY_BUDGET_CENTS,
        topeMensualCentavos: this.config.SMS_MONTHLY_BUDGET_CENTS,
      },
    };
  }
}
