/** Public interface of the Notifications module. Other modules may only import from here. */
export { NotificationsModule } from './notifications.module.js';
export {
  SEND_NOTIFICATION_JOB,
  type SendNotificationJob,
} from './application/send-notification.job.js';
