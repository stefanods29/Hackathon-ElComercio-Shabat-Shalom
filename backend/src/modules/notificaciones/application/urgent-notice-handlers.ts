import { Injectable, type OnModuleInit } from '@nestjs/common';
import { z } from 'zod';
import { JobHandlerRegistry } from '../../../shared/queues/job-handler.registry.js';
import {
  URGENT_NOTICE_JOB,
  URGENT_REVIEW_JOB,
  URGENT_TEMPLATES,
  type UrgentNoticeJob,
} from './urgent-notice.job.js';
import { UrgentNotices } from './urgent-notices.js';

const id = z.uuid();
const urgentJobSchema = z.strictObject({
  avisoId: id,
  usuarioId: id,
  plantilla: z.enum(URGENT_TEMPLATES),
  datos: z.strictObject({ casoId: id.optional() }),
});
const reviewJobSchema = z.strictObject({ avisoId: id });

@Injectable()
export class UrgentNoticeHandlers implements OnModuleInit {
  constructor(
    private readonly registry: JobHandlerRegistry,
    private readonly notices: UrgentNotices,
  ) {}

  onModuleInit(): void {
    this.registry.register(URGENT_NOTICE_JOB, (data) => this.notices.send(this.urgentJob(data)));
    this.registry.register(URGENT_REVIEW_JOB, (data) =>
      this.notices.review(reviewJobSchema.parse(data).avisoId),
    );
  }

  private urgentJob(data: unknown): UrgentNoticeJob {
    const job = urgentJobSchema.parse(data);
    return {
      avisoId: job.avisoId,
      usuarioId: job.usuarioId,
      plantilla: job.plantilla,
      datos: job.datos.casoId ? { casoId: job.datos.casoId } : {},
    };
  }
}
