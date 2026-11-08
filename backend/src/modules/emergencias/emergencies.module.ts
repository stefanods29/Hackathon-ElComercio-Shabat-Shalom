import { Module } from '@nestjs/common';
import { EmergencyPersonalData } from './infrastructure/emergency-personal-data.kysely.js';

/**
 * Emergencies module: Phase 0 skeleton. Its owner adds controllers and providers here following the
 * reference pattern in `modules/solidaridad`.
 */
@Module({ providers: [EmergencyPersonalData] })
export class EmergenciesModule {}
