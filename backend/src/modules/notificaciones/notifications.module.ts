import { Module } from '@nestjs/common';
import { NotificationPersonalData } from './infrastructure/notification-personal-data.kysely.js';
import { APP_CONFIG, type AppConfig } from '../../shared/config/app-config.js';
import { DevicesController } from './api/devices.controller.js';
import {
  NOTIFICATION_PORT,
  DEVICE_REGISTRATION,
  NOTIFICATION_DELIVERY,
} from './application/ports.js';
import { DeviceRepository } from './infrastructure/device.repository.js';
import { DeliveryRepository } from './infrastructure/delivery.repository.js';
import { NotificationHandlers } from './application/notification-handlers.js';
import { FakeNotificationAdapter } from './infrastructure/notification.fake.js';
import { FcmNotificationAdapter } from './infrastructure/notification.fcm.js';

/**
 * Composes private device registration and notification delivery behind application ports.
 */
@Module({
  controllers: [DevicesController],
  providers: [
    NotificationPersonalData,
    { provide: DEVICE_REGISTRATION, useClass: DeviceRepository },
    { provide: NOTIFICATION_DELIVERY, useClass: DeliveryRepository },
    NotificationHandlers,
    {
      provide: NOTIFICATION_PORT,
      inject: [APP_CONFIG],
      useFactory: (config: AppConfig) =>
        config.NOTIFICATION_DRIVER === 'fcm'
          ? new FcmNotificationAdapter(config.FIREBASE_SERVICE_ACCOUNT_BASE64!)
          : new FakeNotificationAdapter(),
    },
  ],
})
export class NotificationsModule {}
