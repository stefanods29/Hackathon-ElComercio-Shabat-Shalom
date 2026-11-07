import { Body, Controller, HttpCode, Post, Req } from '@nestjs/common';
import type { Request } from 'express';
import { V1 } from '../../../shared/api/routes.js';
import { Public } from '../../../shared/auth/decorators.js';
import { RequestOtp } from '../application/request-otp.js';
import { VerifyOtp } from '../application/verify-otp.js';
import {
  type RequestOtpDto,
  type SessionResponse,
  type VerifyOtpDto,
  requestOtpSchema,
  toSessionResponse,
  verifyOtpSchema,
} from './schemas.js';

@Controller(`${V1}/auth`)
@Public()
export class AuthController {
  constructor(
    private readonly requestOtp: RequestOtp,
    private readonly verifyOtp: VerifyOtp,
  ) {}

  @Post('otp')
  @HttpCode(202)
  async requestCode(
    @Body({ schema: requestOtpSchema }) body: RequestOtpDto,
    @Req() request: Request,
  ): Promise<{ reintentarEnSegundos: number; expiraEnSegundos: number }> {
    const result = await this.requestOtp.execute({
      phone: body.telefono,
      channel: body.canal,
      ip: request.ip ?? null,
    });
    return {
      reintentarEnSegundos: result.retryAfterSeconds,
      expiraEnSegundos: result.expiresInSeconds,
    };
  }

  @Post('otp/verificar')
  @HttpCode(200)
  async verifyCode(
    @Body({ schema: verifyOtpSchema }) body: VerifyOtpDto,
    @Req() request: Request,
  ): Promise<SessionResponse> {
    const session = await this.verifyOtp.execute({
      phone: body.telefono,
      code: body.codigo,
      ip: request.ip ?? null,
      device: body.dispositivo,
    });
    return toSessionResponse(session);
  }
}
