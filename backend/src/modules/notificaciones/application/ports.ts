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

export interface NotificationDelivery {
  deliver(job: SendNotificationJob, message: PushMessage, push: NotificationPort): Promise<void>;
}

export const DEVICE_REGISTRATION = Symbol('DEVICE_REGISTRATION');
export const NOTIFICATION_DELIVERY = Symbol('NOTIFICATION_DELIVERY');
