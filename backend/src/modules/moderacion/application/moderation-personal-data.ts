import { Injectable, type OnModuleInit } from '@nestjs/common';
import {
  PersonalDataRegistry,
  type PersonalDataParticipant,
} from '../../../shared/privacy/personal-data.registry.js';

@Injectable()
export class ModerationPersonalData implements OnModuleInit, PersonalDataParticipant {
  constructor(private readonly registry: PersonalDataRegistry) {}

  onModuleInit(): void {
    this.registry.register('moderacion', this);
  }

  // Current automatic cases only link to content. Part 5 adds user-owned reports and sanctions.
  async read() {
    return { denuncias: [] };
  }

  async erase(): Promise<void> {
    // No report or sanction records belong to a user in this part.
  }
}
