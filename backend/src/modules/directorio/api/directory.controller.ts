import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Post,
  Put,
  Query,
  Res,
} from '@nestjs/common';
import type { Response } from 'express';
import { V1 } from '../../../shared/api/routes.js';
import type { Actor } from '../../../shared/auth/actor.js';
import { CurrentActor, RequireTrustLevel } from '../../../shared/auth/decorators.js';
import { Idempotent } from '../../../shared/idempotency/idempotent.decorator.js';
import { FindServices } from '../application/find-services.js';
import { EditService } from '../application/edit-service.js';
import { PublishService } from '../application/publish-service.js';
import { ReadDirectory } from '../application/read-directory.js';
import { SaveProvider } from '../application/save-provider.js';
import { WithdrawService } from '../application/withdraw-service.js';
import {
  serviceSearchSchema,
  type ServiceSearchDto,
  directoryIdSchema,
  editServiceSchema,
  newServiceSchema,
  providerSchema,
  toCategoryDto,
  toProviderDto,
  toServiceData,
  toServiceDto,
  type EditServiceDto,
  type NewServiceDto,
  type ProviderDto,
} from './schemas.js';

@Controller(V1)
export class DirectoryController {
  constructor(
    private readonly readDirectory: ReadDirectory,
    private readonly findServices: FindServices,
    private readonly saveProvider: SaveProvider,
    private readonly publishService: PublishService,
    private readonly editService: EditService,
    private readonly withdrawService: WithdrawService,
  ) {}

  @Get('servicios')
  async search(
    @Query({ schema: serviceSearchSchema }) query: ServiceSearchDto,
    @CurrentActor() actor: Actor,
  ) {
    const page = await this.findServices.execute(
      {
        location: { lat: query.lat, lng: query.lng },
        radiusMeters: query.radioM,
        categoryId: query.categoriaId,
        text: query.q,
        emergencyOnly: query.soloEmergencia,
        cursor: query.cursor,
        limit: query.limite,
      },
      actor,
    );
    return {
      datos: page.data.map((hit) => ({
        ...toServiceDto(hit.service),
        distanciaMetros: hit.distanceMeters,
      })),
      siguienteCursor: page.nextCursor,
    };
  }

  @Get('categorias')
  async categories() {
    return { datos: (await this.readDirectory.categories()).map(toCategoryDto) };
  }

  @Put('yo/proveedor')
  @RequireTrustLevel(1)
  @Idempotent()
  @HttpCode(200)
  async save(@Body({ schema: providerSchema }) body: ProviderDto, @CurrentActor() actor: Actor) {
    return toProviderDto(
      await this.saveProvider.execute(
        { publicName: body.nombrePublico, description: body.descripcion ?? null },
        actor,
      ),
    );
  }

  @Post('servicios')
  @RequireTrustLevel(1)
  @Idempotent()
  @HttpCode(201)
  async publish(
    @Body({ schema: newServiceSchema }) body: NewServiceDto,
    @CurrentActor() actor: Actor,
    @Res({ passthrough: true }) response: Response,
  ) {
    const result = await this.publishService.execute(
      { id: body.id, ...toServiceData(body) },
      actor,
    );
    if (!result.created) response.status(200);
    return toServiceDto(result.service);
  }

  @Put('servicios/:id')
  @Idempotent()
  @HttpCode(200)
  async edit(
    @Param('id', { schema: directoryIdSchema }) id: string,
    @Body({ schema: editServiceSchema }) body: EditServiceDto,
    @CurrentActor() actor: Actor,
  ) {
    return toServiceDto(
      await this.editService.execute(id, body.versionVista, toServiceData(body), actor),
    );
  }

  @Delete('servicios/:id')
  @Idempotent()
  @HttpCode(204)
  async withdraw(
    @Param('id', { schema: directoryIdSchema }) id: string,
    @CurrentActor() actor: Actor,
  ): Promise<void> {
    await this.withdrawService.execute(id, actor);
  }

  @Get('proveedores/:id')
  async provider(@Param('id', { schema: directoryIdSchema }) id: string) {
    const result = await this.readDirectory.provider(id);
    return {
      ...toProviderDto(result.provider),
      servicios: result.services.map(toServiceDto),
    };
  }
}
