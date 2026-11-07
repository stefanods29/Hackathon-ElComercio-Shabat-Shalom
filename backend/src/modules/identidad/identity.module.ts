import { Module } from '@nestjs/common';
import { APP_CONFIG, type AppConfig } from '../../shared/config/app-config.js';
import { AuthController } from './api/auth.controller.js';
import { SessionsController } from './api/sessions.controller.js';
import { ZonesController } from './api/zones.controller.js';
import { ChooseZone } from './application/choose-zone.js';
import { IssueCredentials } from './application/issue-credentials.js';
import { ListZones } from './application/list-zones.js';
import {
  OTP_CODE_REPOSITORY,
  OTP_PROVIDER,
  USER_REPOSITORY,
  ZONE_REPOSITORY,
} from './application/ports.js';
import { RequestOtp } from './application/request-otp.js';
import { VerifyOtp } from './application/verify-otp.js';
import { FakeOtpProvider } from './infrastructure/fake-otp.provider.js';
import { KyselyOtpCodeRepository } from './infrastructure/otp-code.repository.kysely.js';
import { TwilioOtpProvider } from './infrastructure/twilio-otp.provider.js';
import { KyselyUserRepository } from './infrastructure/user.repository.kysely.js';
import { KyselyZoneRepository } from './infrastructure/zone.repository.kysely.js';

@Module({
  controllers: [AuthController, SessionsController, ZonesController],
  providers: [
    IssueCredentials,
    RequestOtp,
    VerifyOtp,
    ListZones,
    ChooseZone,
    { provide: USER_REPOSITORY, useClass: KyselyUserRepository },
    { provide: ZONE_REPOSITORY, useClass: KyselyZoneRepository },
    { provide: OTP_CODE_REPOSITORY, useClass: KyselyOtpCodeRepository },
    {
      provide: OTP_PROVIDER,
      inject: [APP_CONFIG],
      useFactory: (config: AppConfig) =>
        config.OTP_PROVIDER === 'twilio'
          ? new TwilioOtpProvider(config)
          : new FakeOtpProvider(config),
    },
  ],
})
export class IdentityModule {}
