import {
  type ExecutionContext,
  SetMetadata,
  UnauthorizedException,
  createParamDecorator,
} from '@nestjs/common';
import type { Actor, AuthenticatedRequest } from './actor.js';

export const PUBLIC_METADATA = 'vecinal:public';

/** Route without a token (health, JWKS, sign-in). Everything else requires a token by default. */
export const Public = (): MethodDecorator & ClassDecorator => SetMetadata(PUBLIC_METADATA, true);

/** Injects the authenticated actor into the controller. */
export const CurrentActor = createParamDecorator(
  (_data: unknown, context: ExecutionContext): Actor => {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    if (!request.actor) {
      throw new UnauthorizedException('Esta acción requiere iniciar sesión.');
    }
    return request.actor;
  },
);
