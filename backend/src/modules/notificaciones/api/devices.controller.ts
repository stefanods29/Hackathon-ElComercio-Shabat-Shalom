import { Body, Controller, HttpCode, Inject, Post } from '@nestjs/common';
import { z } from 'zod';
import type { Actor } from '../../../shared/auth/actor.js';
import { CurrentActor } from '../../../shared/auth/decorators.js';
import { Idempotent } from '../../../shared/idempotency/idempotent.decorator.js';
import { DEVICE_REGISTRATION, type DeviceRegistration } from '../application/ports.js';

const tokenSchema = z
  .string()
  .min(1)
  .max(4096)
  .regex(/^[!-~]+$/);
const registerSchema = z.strictObject({
  token: tokenSchema,
  plataforma: z.enum(['android', 'ios']),
});
const unregisterSchema = z.strictObject({ token: tokenSchema });

@Controller('v1/dispositivos')
export class DevicesController {
  constructor(@Inject(DEVICE_REGISTRATION) private readonly devices: DeviceRegistration) {}

  @Post()
  @Idempotent()
  @HttpCode(200)
  async register(
    @Body({ schema: registerSchema }) body: z.infer<typeof registerSchema>,
    @CurrentActor() actor: Actor,
  ) {
    return this.devices.register(actor.id, body.token, body.plataforma);
  }

  @Post('baja')
  @Idempotent()
  @HttpCode(204)
  async unregister(
    @Body({ schema: unregisterSchema }) body: z.infer<typeof unregisterSchema>,
    @CurrentActor() actor: Actor,
  ): Promise<void> {
    await this.devices.unregister(actor.id, body.token);
  }
}
