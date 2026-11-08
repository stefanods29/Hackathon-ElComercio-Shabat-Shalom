/** Public interface of the Notifications module. Other modules may only import from here. */
export { NotificationsModule } from './notifications.module.js';
export {
  URGENT_NOTICE_JOB,
  type UrgentNoticeJob,
  type UrgentTemplate,
} from './application/urgent-notice.job.js';
export {
  SEND_NOTIFICATION_JOB,
  type SendNotificationJob,
} from './application/send-notification.job.js';
