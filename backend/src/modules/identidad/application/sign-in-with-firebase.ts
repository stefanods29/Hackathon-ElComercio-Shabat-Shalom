import { Inject, Injectable } from '@nestjs/common';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import { AuthenticationFailure } from '../../../shared/domain/errors.js';
import { CreateSession, type IssuedRefreshSession } from './create-session.js';
import {
  PHONE_TOKEN_VERIFIER,
  USER_REPOSITORY,
  type PhoneTokenVerifier,
  type UserRepository,
} from './ports.js';

/** The app exchanges the token right after the SMS code; an older one is not accepted. */
const MAX_TOKEN_AGE_MS = 10 * 60_000;

export interface SignInWithFirebaseCommand {
  readonly token: string;
  readonly device?: string;
}

/**
 * Firebase Authentication sends and checks the SMS code in the app. The API only trusts the
 * resulting ID token and then opens the same session as the OTP flow.
 */
@Injectable()
export class SignInWithFirebase {
  constructor(
    @Inject(UNIT_OF_WORK) private readonly unitOfWork: UnitOfWork,
    @Inject(USER_REPOSITORY) private readonly users: UserRepository,
    @Inject(PHONE_TOKEN_VERIFIER) private readonly verifier: PhoneTokenVerifier,
    private readonly createSession: CreateSession,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  async execute(command: SignInWithFirebaseCommand): Promise<IssuedRefreshSession> {
    const verified = await this.verifier.verify(command.token);
    const age = verified ? this.clock.now().getTime() - verified.verifiedAt.getTime() : Infinity;
    if (!verified || age > MAX_TOKEN_AGE_MS) {
      throw new AuthenticationFailure(
        'token_firebase_invalido',
        'No pudimos confirmar tu número. Vuelve a pedir el código.',
      );
    }
    return this.unitOfWork.run(async (transaction) => {
      const user = await this.users.findOrCreateByPhone(transaction, verified.phone);
      return this.createSession.inTransaction(transaction, user, command.device ?? null);
    });
  }
}
