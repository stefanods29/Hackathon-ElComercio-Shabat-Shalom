import {
  Inject,
  Injectable,
  Module,
  type OnApplicationBootstrap,
  type OnModuleDestroy,
  type OnModuleInit,
} from '@nestjs/common';
import { DirectoryModule } from '../modules/directorio/index.js';
import { NotificationsModule } from '../modules/notificaciones/index.js';
import { AppConfigModule } from '../shared/config/app-config.module.js';
import { DatabaseModule } from '../shared/db/database.module.js';
import { OutboxRelay } from '../shared/outbox/outbox-relay.js';
import { OutboxRelayLoop } from '../shared/outbox/outbox-relay-loop.js';
import { DAILY_CLEANUP_JOB, DailyCleanup } from '../shared/queues/daily-cleanup.js';
import { JobHandlerRegistry } from '../shared/queues/job-handler.registry.js';
import { JOB_QUEUE, type JobQueue } from '../shared/queues/job-queue.js';
import { PgBossJobQueue } from '../shared/queues/job-queue.pgboss.js';
import { SharedModule } from '../shared/shared.module.js';

@Injectable()
export class WorkerRuntime implements OnModuleInit, OnApplicationBootstrap, OnModuleDestroy {
  private readonly loop: OutboxRelayLoop;

  constructor(
    @Inject(JOB_QUEUE) private readonly queue: JobQueue,
    private readonly registry: JobHandlerRegistry,
    relay: OutboxRelay,
    private readonly cleanup: DailyCleanup,
  ) {
    this.loop = new OutboxRelayLoop(relay);
  }

  onModuleInit(): void {
    this.registry.register(DAILY_CLEANUP_JOB, async () => {
      await this.cleanup.run();
    });
  }

  async onApplicationBootstrap(): Promise<void> {
    if (!(this.queue instanceof PgBossJobQueue)) {
      throw new Error('El proceso de workers requiere JOB_QUEUE_DRIVER=pgboss.');
    }
    await this.registry.startAll(this.queue);
    await this.queue.schedule(DAILY_CLEANUP_JOB, '0 4 * * *', 'America/Lima');
    this.loop.start();
  }

  async onModuleDestroy(): Promise<void> {
    await this.loop.stop();
  }
}

@Module({
  imports: [
    AppConfigModule,
    DatabaseModule,
    SharedModule.forWorkers(),
    NotificationsModule,
    DirectoryModule,
  ],
  providers: [OutboxRelay, DailyCleanup, WorkerRuntime],
})
export class WorkersModule {}
