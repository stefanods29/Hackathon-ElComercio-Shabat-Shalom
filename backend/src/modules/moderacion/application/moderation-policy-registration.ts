import { Inject, Injectable, type OnModuleInit } from '@nestjs/common';
import { PublicationPolicy } from '../../../shared/moderation/publication-policy.js';
import { MODERATION_STORE, type ModerationStore } from './ports.js';

export const IS_SUSPENDED = Symbol('IS_SUSPENDED');

@Injectable()
export class ModerationPolicyRegistration implements OnModuleInit {
  constructor(
    private readonly policy: PublicationPolicy,
    @Inject(MODERATION_STORE) private readonly store: ModerationStore,
  ) {}

  onModuleInit(): void {
    this.policy.register((id, now, tx) => this.store.isSuspended(id, now, tx));
  }
}
