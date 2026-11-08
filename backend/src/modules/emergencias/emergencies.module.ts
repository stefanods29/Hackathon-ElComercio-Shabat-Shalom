import { Module } from '@nestjs/common';
import { IdentityModule } from '../identidad/index.js';
import { EmergencyPersonalData } from './infrastructure/emergency-personal-data.kysely.js';
import { EmergencyEventsController } from './api/events.controller.js';
import { HelpRequestsController } from './api/requests.controller.js';
import { EmergencyOperationsController } from './api/operations.controller.js';
import { EmergencyResourcesController } from './api/resources.controller.js';
import { ManageEvents } from './application/manage-events.js';
import { ManageHelpRequests } from './application/manage-help-requests.js';
import { ManageOperations } from './application/manage-operations.js';
import { ManageResources } from './application/manage-resources.js';
import { OperationalAccess } from './application/operational-access.js';
import { EmergencyJobs } from './application/emergency-jobs.js';
import {
  AUDIT_STORE,
  EVENT_STORE,
  OFFICIAL_ALERT_SOURCE,
  OPERATIONS_STORE,
  REQUEST_STORE,
  RESOURCE_STORE,
} from './application/ports.js';
import { PostgresAuditStore } from './infrastructure/audit.store.js';
import { PostgresEventStore } from './infrastructure/event.store.js';
import { PostgresOperationsStore } from './infrastructure/operations.store.js';
import { PostgresRequestStore } from './infrastructure/request.store.js';
import { PostgresResourceStore } from './infrastructure/resource.store.js';
import { ConfiguredOfficialAlertSource } from './infrastructure/official-alert.source.js';

/** Private emergency operation. Its jobs run in the existing worker process. */
@Module({
  imports: [IdentityModule],
  controllers: [
    EmergencyEventsController,
    HelpRequestsController,
    EmergencyOperationsController,
    EmergencyResourcesController,
  ],
  providers: [
    EmergencyPersonalData,
    ManageEvents,
    ManageHelpRequests,
    ManageOperations,
    ManageResources,
    OperationalAccess,
    EmergencyJobs,
    { provide: EVENT_STORE, useClass: PostgresEventStore },
    { provide: REQUEST_STORE, useClass: PostgresRequestStore },
    { provide: OPERATIONS_STORE, useClass: PostgresOperationsStore },
    { provide: RESOURCE_STORE, useClass: PostgresResourceStore },
    { provide: AUDIT_STORE, useClass: PostgresAuditStore },
    { provide: OFFICIAL_ALERT_SOURCE, useClass: ConfiguredOfficialAlertSource },
  ],
  exports: [ManageEvents, ManageHelpRequests, OFFICIAL_ALERT_SOURCE],
})
export class EmergenciesModule {}
