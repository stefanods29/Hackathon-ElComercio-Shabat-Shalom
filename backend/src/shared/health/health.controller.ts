import { Controller, Get, Inject, Res } from '@nestjs/common';
import type { Response } from 'express';
import { type Kysely, sql } from 'kysely';
import { V1 } from '../api/routes.js';
import { Public } from '../auth/decorators.js';
import { KYSELY } from '../db/connection.js';
import { CLOCK, type Clock } from '../domain/clock.js';

/** JSON fields are part of the public contract and stay in Spanish. */
export interface HealthResponse {
  estado: 'ok' | 'degradado';
  baseDeDatos: 'ok' | 'caida';
  hora: string;
}

/** Probe for the load balancer and monitoring: 200 when healthy, 503 when the database is down. */
@Controller(`${V1}/salud`)
@Public()
export class HealthController {
  constructor(
    @Inject(KYSELY) private readonly db: Kysely<unknown>,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  @Get()
  async check(@Res({ passthrough: true }) response: Response): Promise<HealthResponse> {
    let database: HealthResponse['baseDeDatos'] = 'ok';
    try {
      await sql`select 1`.execute(this.db);
    } catch {
      database = 'caida';
      response.status(503);
    }
    return {
      estado: database === 'ok' ? 'ok' : 'degradado',
      baseDeDatos: database,
      hora: this.clock.now().toISOString(),
    };
  }
}
