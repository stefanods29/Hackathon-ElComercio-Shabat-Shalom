import { Module } from '@nestjs/common';
import { CurationModule } from './modules/curaduria/index.js';
import { DirectoryModule } from './modules/directorio/index.js';
import { EmergenciesModule } from './modules/emergencias/index.js';
import { IdentityModule } from './modules/identidad/index.js';
import { MediaModule } from './modules/media/index.js';
import { ModerationModule } from './modules/moderacion/index.js';
import { NotificationsModule } from './modules/notificaciones/index.js';
import { ReputationModule } from './modules/reputacion/index.js';
import { SolidarityModule } from './modules/solidaridad/index.js';
import { AppConfigModule } from './shared/config/app-config.module.js';
import { DatabaseModule } from './shared/db/database.module.js';
import { SharedModule } from './shared/shared.module.js';

/** Composition root of the modular monolith: the only place that knows every module. */
@Module({
  imports: [
    AppConfigModule,
    DatabaseModule,
    SharedModule,
    IdentityModule,
    DirectoryModule,
    ReputationModule,
    SolidarityModule,
    EmergenciesModule,
    NotificationsModule,
    MediaModule,
    ModerationModule,
    CurationModule,
  ],
})
export class AppModule {}
