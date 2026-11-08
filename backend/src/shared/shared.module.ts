import {
  type DynamicModule,
  Global,
  Module,
  type MiddlewareConsumer,
  type NestModule,
} from '@nestjs/common';
import { APP_FILTER, APP_GUARD, APP_INTERCEPTOR, APP_PIPE } from '@nestjs/core';
import type { Kysely } from 'kysely';
import { ProblemDetailsFilter } from './api/problem-details.filter.js';
import { createValidationPipe } from './api/validation.js';
import { AccountAccess } from './auth/account-access.js';
import { PersonalDataRegistry } from './privacy/personal-data.registry.js';
import { SharedPersonalData } from './privacy/shared-personal-data.js';
import { AuthGuard } from './auth/auth.guard.js';
import { AuthorizationGuard } from './auth/authorization.guard.js';
import { JwksController } from './auth/jwks.controller.js';
import { TokenService } from './auth/token.service.js';
import { APP_CONFIG, type AppConfig } from './config/app-config.js';
import { KYSELY } from './db/connection.js';
import type { SharedTables } from './db/shared-tables.js';
import { CLOCK, systemClock } from './domain/clock.js';
import { HealthController } from './health/health.controller.js';
import { IDEMPOTENCY_STORE } from './idempotency/idempotency-store.js';
import { PostgresIdempotencyStore } from './idempotency/idempotency-store.postgres.js';
import { IdempotencyInterceptor } from './idempotency/idempotency.interceptor.js';
import { OUTBOX_WRITER } from './outbox/outbox.js';
import { PostgresOutboxWriter } from './outbox/outbox.postgres.js';
import { JOB_QUEUE } from './queues/job-queue.js';
import { InMemoryJobQueue } from './queues/job-queue.memory.js';
import { PgBossJobQueue } from './queues/job-queue.pgboss.js';
import { JobHandlerRegistry } from './queues/job-handler.registry.js';
import { QUEUE_METRICS_READER } from './queues/queue-metrics.js';
import { IdempotencyCounters } from './observability/idempotency-counters.js';
import { HttpRequestLogger, RequestIdMiddleware } from './observability/request-id.middleware.js';
import { OperationalMetrics } from './observability/operational-metrics.js';
import { MetricsController } from './observability/metrics.controller.js';

function queueProvider(worker = false) {
  return {
    provide: JOB_QUEUE,
    inject: [APP_CONFIG],
    useFactory: (config: AppConfig) =>
      config.JOB_QUEUE_DRIVER === 'memory'
        ? new InMemoryJobQueue()
        : new PgBossJobQueue(config, { worker }),
  };
}

/**
 * Shared core: RFC 9457 errors, Standard Schema validation, global authentication,
 * idempotency, outbox and the job queue port. Modules use it; never the other way around.
 */
@Global()
@Module({
  controllers: [JwksController, HealthController, MetricsController],
  providers: [
    { provide: CLOCK, useValue: systemClock },
    TokenService,
    AccountAccess,
    PersonalDataRegistry,
    SharedPersonalData,
    {
      provide: IDEMPOTENCY_STORE,
      inject: [KYSELY, APP_CONFIG, AccountAccess],
      useFactory: (db: Kysely<SharedTables>, config: AppConfig, accounts: AccountAccess) =>
        new PostgresIdempotencyStore(db, config.IDEMPOTENCY_RETENTION_HOURS, accounts),
    },
    { provide: OUTBOX_WRITER, useClass: PostgresOutboxWriter },
    queueProvider(),
    JobHandlerRegistry,
    IdempotencyCounters,
    HttpRequestLogger,
    RequestIdMiddleware,
    OperationalMetrics,
    {
      provide: QUEUE_METRICS_READER,
      inject: [JOB_QUEUE],
      useFactory: (queue: InMemoryJobQueue | PgBossJobQueue) => queue,
    },
    { provide: APP_FILTER, useClass: ProblemDetailsFilter },
    { provide: APP_PIPE, useFactory: createValidationPipe },
    { provide: APP_GUARD, useClass: AuthGuard },
    { provide: APP_GUARD, useClass: AuthorizationGuard },
    { provide: APP_INTERCEPTOR, useClass: IdempotencyInterceptor },
  ],
  exports: [
    CLOCK,
    TokenService,
    AccountAccess,
    PersonalDataRegistry,
    IDEMPOTENCY_STORE,
    OUTBOX_WRITER,
    JOB_QUEUE,
    JobHandlerRegistry,
  ],
})
export class SharedModule implements NestModule {
  configure(consumer: MiddlewareConsumer): void {
    consumer.apply(RequestIdMiddleware).forRoutes('{*path}');
  }
  static forWorkers(): DynamicModule {
    return { module: SharedModule, providers: [queueProvider(true)] };
  }
}
