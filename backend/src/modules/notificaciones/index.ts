/** Public interface of the Notifications module. Other modules may only import from here. */
export { NotificationsModule } from './notifications.module.js';
export {
  SEND_NOTIFICATION_JOB,
  type SendNotificationJob,
} from './application/send-notification.job.js';
/** Phase 2, Lot C: Emergencies (Lot B) enqueues it when it assigns or escalates a case. */
export {
  URGENT_NOTICE_JOB,
  URGENT_TEMPLATES,
  type UrgentNoticeJob,
  type UrgentTemplate,
} from './application/urgent-notice.job.js';
