import { Body, Controller, Get, HttpCode, Param, Put } from '@nestjs/common';
import { z } from 'zod';
import { V1 } from '../../../shared/api/routes.js';
import type { Actor } from '../../../shared/auth/actor.js';
import { CurrentActor, RequireRole } from '../../../shared/auth/decorators.js';
import { Idempotent } from '../../../shared/idempotency/idempotent.decorator.js';
import { fileNameSchema } from '../application/directory-schema.js';
import { EmergencyDirectories } from '../application/emergency-directories.js';

/**
 * Shape only (400 `validacion`). The content rules of the Phase 1 schema are checked by the use
 * case and answer 422 `directorio_invalido` with one error per field.
 */
const publicationShape = z.strictObject({
  versionVista: z.int().min(1),
  distrito: z.string(),
  entradas: z.array(z.record(z.string(), z.unknown())).min(1).max(500),
});
type PublicationShape = z.infer<typeof publicationShape>;

/** `curador` joins these roles when Lot B (Phase 2, part 5) adds it to the token. */
@Controller(`${V1}/operacion/directorio-emergencia`)
@RequireRole('administrador', 'coordinador')
export class CurationController {
  constructor(private readonly directories: EmergencyDirectories) {}

  @Get()
  list() {
    return this.directories.list();
  }

  @Get(':archivo')
  get(@Param('archivo', { schema: fileNameSchema }) archivo: string) {
    return this.directories.get(archivo);
  }

  @Put(':archivo')
  @Idempotent()
  @HttpCode(200)
  publish(
    @Param('archivo', { schema: fileNameSchema }) archivo: string,
    @Body({ schema: publicationShape }) body: PublicationShape,
    @CurrentActor() actor: Actor,
  ) {
    return this.directories.publish(actor, archivo, body);
  }
}
