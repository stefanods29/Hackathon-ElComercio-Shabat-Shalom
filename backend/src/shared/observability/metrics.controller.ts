import { Controller, Get } from '@nestjs/common';
import { V1 } from '../api/routes.js';
import { RequireRole } from '../auth/decorators.js';
import { OperationalMetrics } from './operational-metrics.js';

@Controller(`${V1}/operacion`)
export class MetricsController {
  constructor(private readonly metrics: OperationalMetrics) {}

  @Get('metricas')
  @RequireRole('administrador')
  snapshot() {
    return this.metrics.snapshot();
  }
}
