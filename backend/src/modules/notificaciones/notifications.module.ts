import { Module } from '@nestjs/common';
import { APP_CONFIG, type AppConfig } from '../../shared/config/app-config.js';
import { IdentityContactsModule } from '../identidad/index.js';
import { DevicesController } from './api/devices.controller.js';
import { UrgentNoticesController } from './api/urgent-notices.controller.js';
import {
  NOTIFICATION_PORT,
  DEVICE_REGISTRATION,
  NOTIFICATION_DELIVERY,
  SMS_PROVIDER,
  URGENT_NOTICES,
} from './application/ports.js';
import { DeviceRepository } from './infrastructure/device.repository.js';
import { DeliveryRepository } from './infrastructure/delivery.repository.js';
import { NotificationHandlers } from './application/notification-handlers.js';
import { UrgentNoticeHandlers } from './application/urgent-notice-handlers.js';
import { UrgentNotices } from './application/urgent-notices.js';
import { FakeNotificationAdapter } from './infrastructure/notification.fake.js';
import { FcmNotificationAdapter } from './infrastructure/notification.fcm.js';
import { DisabledSmsProvider } from './infrastructure/sms.disabled.js';
import { FakeSmsProvider } from './infrastructure/sms.fake.js';
import { UrgentNoticeRepository } from './infrastructure/urgent-notice.repository.js';

/**
 * Composes private device registration and notification delivery behind application ports, plus
 * urgent notices with their SMS backup (Phase 2, Lot C).
 */
@Module({
  imports: [IdentityContactsModule],
  controllers: [DevicesController, UrgentNoticesController],
  providers: [
    { provide: DEVICE_REGISTRATION, useClass: DeviceRepository },
    { provide: NOTIFICATION_DELIVERY, useClass: DeliveryRepository },
    { provide: URGENT_NOTICES, useClass: UrgentNoticeRepository },
    NotificationHandlers,
    UrgentNotices,
    UrgentNoticeHandlers,
    {
      provide: NOTIFICATION_PORT,
      inject: [APP_CONFIG],
      useFactory: (config: AppConfig) =>
        config.NOTIFICATION_DRIVER === 'fcm'
          ? new FcmNotificationAdapter(config.FIREBASE_SERVICE_ACCOUNT_BASE64!)
          : new FakeNotificationAdapter(),
    },
    {
      provide: SMS_PROVIDER,
      inject: [APP_CONFIG],
      useFactory: (config: AppConfig) =>
        config.SMS_PROVIDER === 'fake'
          ? new FakeSmsProvider(config.SMS_COST_CENTS, config.NODE_ENV === 'development')
          : new DisabledSmsProvider(),
    },
  ],
})
export class NotificationsModule {}
