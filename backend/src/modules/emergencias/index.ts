/** Public interface of the Emergencies module. Other modules may only import from here. */
export { EmergenciesModule } from './emergencies.module.js';
export { ManageEvents } from './application/manage-events.js';
export { ManageHelpRequests } from './application/manage-help-requests.js';
export {
  OFFICIAL_ALERT_SOURCE,
  type OfficialAlertSource,
  type OfficialAlert,
} from './application/ports.js';
export {
  EMERGENCY_MAINTENANCE_JOB,
  EMERGENCY_AGGREGATES_JOB,
  EMERGENCY_ALERTS_JOB,
} from './application/emergency-jobs.js';
export type { HelpRequest, RequestState, EmergencyEvent } from './domain/emergency.js';
