import { Body, Controller, HttpCode, Inject, Post, Req } from '@nestjs/common';
import type { Request } from 'express';
import { V1 } from '../../../shared/api/routes.js';
import { Public } from '../../../shared/auth/decorators.js';
import { APP_CONFIG, type AppConfig } from '../../../shared/config/app-config.js';
import { BusinessRuleViolation } from '../../../shared/domain/errors.js';
import { RequestOtp } from '../application/request-otp.js';
import { SignInWithFirebase } from '../application/sign-in-with-firebase.js';
import { VerifyOtp } from '../application/verify-otp.js';
import {
  type FirebaseSignInDto,
  type RequestOtpDto,
  type RenewableSessionResponse,
  type VerifyOtpDto,
  firebaseSignInSchema,
  requestOtpSchema,
  toRenewableSessionResponse,
  verifyOtpSchema,
} from './schemas.js';

@Controller(`${V1}/auth`)
@Public()
export class AuthController {
  constructor(
    private readonly requestOtp: RequestOtp,
    private readonly verifyOtp: VerifyOtp,
    private readonly signInWithFirebase: SignInWithFirebase,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  /** With OTP_PROVIDER=firebase the app verifies the phone with Firebase, not with these routes. */
  private assertOtpEnabled(): void {
    if (this.config.OTP_PROVIDER === 'firebase') {
      throw new BusinessRuleViolation(
        'metodo_no_disponible',
        'Este servidor verifica el teléfono con Firebase desde la app.',
        'conflict',
      );
    }
  }

  @Post('otp')
  @HttpCode(202)
  async requestCode(
    @Body({ schema: requestOtpSchema }) body: RequestOtpDto,
    @Req() request: Request,
  ): Promise<{ reintentarEnSegundos: number; expiraEnSegundos: number }> {
    this.assertOtpEnabled();
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
  ): Promise<RenewableSessionResponse> {
    this.assertOtpEnabled();
    const session = await this.verifyOtp.execute({
      phone: body.telefono,
      code: body.codigo,
      ip: request.ip ?? null,
      device: body.dispositivo,
    });
    return toRenewableSessionResponse(session);
  }

  @Post('firebase')
  @HttpCode(200)
  async signInWithFirebaseToken(
    @Body({ schema: firebaseSignInSchema }) body: FirebaseSignInDto,
  ): Promise<RenewableSessionResponse> {
    const session = await this.signInWithFirebase.execute({
      token: body.tokenFirebase,
      device: body.dispositivo,
    });
    return toRenewableSessionResponse(session);
  }
}
