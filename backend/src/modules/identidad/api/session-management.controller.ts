import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { V1 } from '../../../shared/api/routes.js';
import type { Actor } from '../../../shared/auth/actor.js';
import { CurrentActor, Public } from '../../../shared/auth/decorators.js';
import { LogOut } from '../application/log-out.js';
import { RefreshSession } from '../application/refresh-session.js';
import { RevokeAllSessions } from '../application/revoke-all-sessions.js';
import {
  type RefreshSessionDto,
  type RenewableSessionResponse,
  refreshSessionSchema,
  toRenewableSessionResponse,
} from './schemas.js';

@Controller(`${V1}/auth`)
export class SessionManagementController {
  constructor(
    private readonly refreshSession: RefreshSession,
    private readonly logOut: LogOut,
    private readonly revokeAllSessions: RevokeAllSessions,
  ) {}

  @Post('refrescar')
  @Public()
  @HttpCode(200)
  async refresh(
    @Body({ schema: refreshSessionSchema }) body: RefreshSessionDto,
  ): Promise<RenewableSessionResponse> {
    return toRenewableSessionResponse(await this.refreshSession.execute(body.refreshToken));
  }

  @Post('cerrar-sesion')
  @HttpCode(204)
  async close(@CurrentActor() actor: Actor): Promise<void> {
    await this.logOut.execute(actor);
  }

  @Post('sesiones/revocar')
  @HttpCode(204)
  async revokeAll(@CurrentActor() actor: Actor): Promise<void> {
    await this.revokeAllSessions.execute(actor);
  }
}
