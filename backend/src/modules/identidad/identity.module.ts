import { AUTHOR_TRUST } from './application/author-trust.js';
import { KyselyAuthorTrust } from './infrastructure/author-trust.kysely.js';
import { REVIEWER_READER } from './application/reviewer-reader.js';
import { KyselyReviewerReader } from './infrastructure/reviewer.reader.kysely.js';
import { Module } from '@nestjs/common';
import { APP_CONFIG, type AppConfig } from '../../shared/config/app-config.js';
import { PrivacyController } from './api/privacy.controller.js';
import { ACCOUNT_PRIVACY_STORE } from './application/account-privacy-store.js';
import { IdentityJobs } from './application/identity-jobs.js';
import { ManageAccountPrivacy } from './application/manage-account-privacy.js';
import { ManageConsents } from './application/manage-consents.js';
import { RecordResidence } from './application/record-residence.js';
import { RESIDENCE_STORE } from './application/residence-store.js';
import { KyselyIdentityPersonalData } from './infrastructure/identity-personal-data.kysely.js';
import { KyselyResidenceStore } from './infrastructure/residence.store.kysely.js';
import { AuthController } from './api/auth.controller.js';
import { SessionsController } from './api/sessions.controller.js';
import { SessionManagementController } from './api/session-management.controller.js';
import { ZonesController } from './api/zones.controller.js';
import { ChooseZone } from './application/choose-zone.js';
import { CreateSession } from './application/create-session.js';
import { RefreshSession } from './application/refresh-session.js';
import { LogOut } from './application/log-out.js';
import { RevokeAllSessions } from './application/revoke-all-sessions.js';
import { SESSION_REPOSITORY } from './application/session-ports.js';
import { KyselySessionRepository } from './infrastructure/session.repository.kysely.js';
import { IssueCredentials } from './application/issue-credentials.js';
import { ListZones } from './application/list-zones.js';
import {
  OTP_CODE_REPOSITORY,
  OTP_PROVIDER,
  PHONE_TOKEN_VERIFIER,
  USER_REPOSITORY,
  ZONE_REPOSITORY,
} from './application/ports.js';
import { RequestOtp } from './application/request-otp.js';
import { SignInWithFirebase } from './application/sign-in-with-firebase.js';
import { VerifyOtp } from './application/verify-otp.js';
import { DisabledOtpProvider } from './infrastructure/disabled-otp.provider.js';
import { FakeOtpProvider } from './infrastructure/fake-otp.provider.js';
import {
  DisabledPhoneTokenVerifier,
  FirebasePhoneTokenVerifier,
} from './infrastructure/firebase-phone-token.verifier.js';
import { KyselyOtpCodeRepository } from './infrastructure/otp-code.repository.kysely.js';
import { TwilioOtpProvider } from './infrastructure/twilio-otp.provider.js';
import { KyselyUserRepository } from './infrastructure/user.repository.kysely.js';
import { KyselyZoneRepository } from './infrastructure/zone.repository.kysely.js';

@Module({
  controllers: [
    AuthController,
    SessionsController,
    SessionManagementController,
    ZonesController,
    PrivacyController,
  ],
  providers: [
    IssueCredentials,
    { provide: AUTHOR_TRUST, useClass: KyselyAuthorTrust },
    { provide: REVIEWER_READER, useClass: KyselyReviewerReader },
    CreateSession,
    RefreshSession,
    LogOut,
    RevokeAllSessions,
    RequestOtp,
    VerifyOtp,
    SignInWithFirebase,
    ListZones,
    ChooseZone,
    ManageAccountPrivacy,
    ManageConsents,
    RecordResidence,
    IdentityJobs,
    KyselyIdentityPersonalData,
    { provide: ACCOUNT_PRIVACY_STORE, useExisting: KyselyIdentityPersonalData },
    { provide: RESIDENCE_STORE, useClass: KyselyResidenceStore },
    { provide: USER_REPOSITORY, useClass: KyselyUserRepository },
    { provide: ZONE_REPOSITORY, useClass: KyselyZoneRepository },
    { provide: OTP_CODE_REPOSITORY, useClass: KyselyOtpCodeRepository },
    { provide: SESSION_REPOSITORY, useClass: KyselySessionRepository },
    {
      provide: OTP_PROVIDER,
      inject: [APP_CONFIG],
      useFactory: (config: AppConfig) => {
        if (config.OTP_PROVIDER === 'firebase') return new DisabledOtpProvider();
        return config.OTP_PROVIDER === 'twilio'
          ? new TwilioOtpProvider(config)
          : new FakeOtpProvider(config);
      },
    },
    {
      provide: PHONE_TOKEN_VERIFIER,
      inject: [APP_CONFIG],
      useFactory: (config: AppConfig) =>
        config.FIREBASE_PROJECT_ID
          ? new FirebasePhoneTokenVerifier(config.FIREBASE_PROJECT_ID)
          : new DisabledPhoneTokenVerifier(),
    },
  ],
  exports: [REVIEWER_READER, AUTHOR_TRUST],
})
export class IdentityModule {}
