import type { SendNotificationJob } from './send-notification.job.js';

export interface PushMessage {
  readonly title: string;
  readonly body: string;
  readonly data: Readonly<Record<string, string>>;
}

export interface NotificationPort {
  sendToToken(token: string, message: PushMessage): Promise<'sent' | 'invalid_token'>;
  sendToTopic(topic: string, message: PushMessage): Promise<void>;
}

export const NOTIFICATION_PORT = Symbol('NOTIFICATION_PORT');

export interface DeviceRegistrationResult {
  readonly id: string;
  readonly plataforma: 'android' | 'ios';
  readonly registradoEn: string;
}

export interface DeviceRegistration {
  register(
    userId: string,
    token: string,
    platform: 'android' | 'ios',
  ): Promise<DeviceRegistrationResult>;
  unregister(userId: string, token: string): Promise<void>;
}

/** What the idempotent delivery needs: a `SendNotificationJob` and an urgent notice both fit. */
export interface DeliveryRequest {
  readonly avisoId: string;
  readonly destino: SendNotificationJob['destino'];
  readonly plantilla: string;
}

export interface NotificationDelivery {
  deliver(job: DeliveryRequest, message: PushMessage, push: NotificationPort): Promise<void>;
  /** Devices that accepted the notice: 0 without devices or when every token was invalid. */
  deliveredCount(avisoId: string): Promise<number>;
}

export const DEVICE_REGISTRATION = Symbol('DEVICE_REGISTRATION');
export const NOTIFICATION_DELIVERY = Symbol('NOTIFICATION_DELIVERY');

// ── Phase 2, Lot C · urgent notices with SMS backup ─────────────────────────────────────────

export type SmsResult =
  | { readonly status: 'sent'; readonly costCents: number }
  | { readonly status: 'failed'; readonly retryable: boolean };

/** SMS provider port (decision 13.3.4 is open: only the fake adapter exists). */
export interface SmsProvider {
  /** `none` means the backup is switched off on purpose. */
  readonly name: 'none' | 'fake';
  /** Sends a generic text. Implementations must never log the full phone number. */
  send(phone: string, text: string): Promise<SmsResult>;
}

export const SMS_PROVIDER = Symbol('SMS_PROVIDER');

export type UrgentNoticeState =
  | 'esperando_confirmacion'
  | 'confirmado'
  | 'sms_enviando'
  | 'sms_enviado'
  | 'sin_respaldo';

export type NoBackupReason = 'tope_de_gasto' | 'sin_proveedor' | 'sin_telefono' | 'sms_fallido';

export interface UrgentNoticeRecord {
  readonly avisoId: string;
  readonly usuarioId: string;
  readonly plantilla: string;
  readonly casoId: string | null;
  readonly estado: UrgentNoticeState;
  readonly confirmadoEn: Date | null;
  readonly smsIntentos: number;
}

export interface PendingUrgentNotice {
  readonly avisoId: string;
  readonly plantilla: string;
  readonly casoId: string | null;
  readonly creadoEn: Date;
}

export interface SmsBudget {
  readonly now: Date;
  readonly costCents: number;
  readonly dailyCapCents: number;
  readonly monthlyCapCents: number;
}

export interface SmsCostReservation {
  /** Same instant used to reserve: it picks the America/Lima day of the spending row. */
  readonly reservedAt: Date;
  readonly reservedCents: number;
  readonly actualCents: number;
}

/** Outcome of locking a notice for its SMS review. */
export type SmsReservation =
  | { readonly kind: 'nothing_to_do' }
  | { readonly kind: 'reserved'; readonly costCents: number }
  | { readonly kind: 'closed'; readonly reason: NoBackupReason };

export interface UrgentNoticeSummary {
  readonly total: number;
  readonly confirmados: number;
  readonly sinConfirmar: number;
  readonly smsEnviados: number;
  readonly sinRespaldo: Readonly<Record<NoBackupReason, number>>;
  readonly confirmacionSegundos: { readonly p50: number | null; readonly p95: number | null };
  readonly gasto: { readonly hoyCentavos: number; readonly mesCentavos: number };
}

export interface UrgentNoticeStore {
  /** `conflict`: the same avisoId already exists with another recipient or content. */
  claim(input: {
    readonly avisoId: string;
    readonly usuarioId: string;
    readonly plantilla: string;
    readonly casoId: string | null;
    readonly fingerprint: string;
    readonly confirmBefore: Date;
  }): Promise<'created' | 'existing' | 'conflict'>;
  recordReach(avisoId: string, devices: number): Promise<void>;
  find(avisoId: string): Promise<UrgentNoticeRecord | null>;
  /** Marks the notice as acknowledged by its recipient; null when it is not theirs. */
  confirm(avisoId: string, usuarioId: string, now: Date): Promise<Date | null>;
  pendingFor(usuarioId: string, since: Date): Promise<PendingUrgentNotice[]>;
  /** Locks the notice and the day's spending; closes it or reserves the SMS cost atomically. */
  reserveSms(
    avisoId: string,
    budget: SmsBudget,
    checks: { readonly providerEnabled: boolean; readonly hasPhone: boolean },
  ): Promise<SmsReservation>;
  /** Records the SMS and corrects the day's spending if the provider charged another amount. */
  markSmsSent(avisoId: string, sentAt: Date, reservation: SmsCostReservation): Promise<void>;
  /** Gives the reserved cost back; `closeAs` ends the notice, otherwise it can be retried. */
  releaseSms(
    avisoId: string,
    reservation: Omit<SmsCostReservation, 'actualCents'>,
    closeAs?: NoBackupReason,
  ): Promise<void>;
  summary(since: Date, until: Date, now: Date): Promise<UrgentNoticeSummary>;
}

export const URGENT_NOTICES = Symbol('URGENT_NOTICES');
