import {
  type ExecutionContext,
  SetMetadata,
  UnauthorizedException,
  createParamDecorator,
} from '@nestjs/common';
import type { Actor, AuthenticatedRequest, Role } from './actor.js';

export const PUBLIC_METADATA = 'vecinal:public';
export const TRUST_LEVEL_METADATA = 'vecinal:trust-level';
export const ROLES_METADATA = 'vecinal:roles';

/** Route without a token (health, JWKS, sign-in). Everything else requires a token by default. */
export const Public = (): MethodDecorator & ClassDecorator => SetMetadata(PUBLIC_METADATA, true);

export const RequireTrustLevel = (level: number): MethodDecorator & ClassDecorator =>
  SetMetadata(TRUST_LEVEL_METADATA, level);

/** Any listed role grants access; administrator does not implicitly grant the others. */
export const RequireRole = (...roles: Role[]): MethodDecorator & ClassDecorator =>
  SetMetadata(ROLES_METADATA, roles);

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
