import { Body, Controller, Get, HttpCode, Post } from '@nestjs/common';
import { z } from 'zod';
import { V1 } from '../../../shared/api/routes.js';
import type { Actor } from '../../../shared/auth/actor.js';
import { CurrentActor, Public } from '../../../shared/auth/decorators.js';
import { IssueCredentials } from '../application/issue-credentials.js';
import { type SessionResponse, toSessionResponse } from './schemas.js';

/** Contract: `contracts/openapi.yaml` → `SesionDev`. JSON keys stay in Spanish. */
const devSessionSchema = z.object({
  telefono: z
    .string()
    .regex(/^\+[1-9][0-9]{7,14}$/, 'usa el formato internacional, p. ej., +51987654321'),
});

export interface SyncCredentialsResponse {
  endpoint: string;
  token: string;
  expiraEn: string;
}

@Controller(V1)
export class SessionsController {
  constructor(private readonly credentials: IssueCredentials) {}

  /**
   * DEVELOPMENT ONLY: signs in with the phone number of a seeded user. Answers 404 when
   * `ENABLE_DEV_SESSION` is off (always in production). Lot B replaces it with OTP.
   */
  @Post('dev/sesiones')
  @Public()
  @HttpCode(201)
  async startDevSession(
    @Body({ schema: devSessionSchema }) body: z.infer<typeof devSessionSchema>,
  ): Promise<SessionResponse> {
    const session = await this.credentials.startDevSession(body.telefono);
    return toSessionResponse(session);
  }

  /** Called by `fetchCredentials()` of the PowerSync connector on the phone. */
  @Get('sync/credenciales')
  async syncCredentials(@CurrentActor() actor: Actor): Promise<SyncCredentialsResponse> {
    const credentials = await this.credentials.forSync(actor);
    return {
      endpoint: credentials.endpoint,
      token: credentials.token,
      expiraEn: credentials.expiresAt.toISOString(),
    };
  }
}
