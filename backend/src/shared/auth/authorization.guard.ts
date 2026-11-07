import {
  type CanActivate,
  type ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { BusinessRuleViolation } from '../domain/errors.js';
import type { AuthenticatedRequest, Role } from './actor.js';
import { PUBLIC_METADATA, ROLES_METADATA, TRUST_LEVEL_METADATA } from './decorators.js';

@Injectable()
export class AuthorizationGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const isPublic = this.reflector.getAllAndOverride<boolean | undefined>(PUBLIC_METADATA, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic || context.getType() !== 'http') {
      return true;
    }

    const requiredTrustLevel = this.reflector.getAllAndOverride<number | undefined>(
      TRUST_LEVEL_METADATA,
      [context.getHandler(), context.getClass()],
    );
    const requiredRoles = this.reflector.getAllAndOverride<readonly Role[] | undefined>(
      ROLES_METADATA,
      [context.getHandler(), context.getClass()],
    );
    if (requiredTrustLevel === undefined && !requiredRoles?.length) {
      return true;
    }

    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const actor = request.actor;
    if (!actor) {
      throw new UnauthorizedException('Esta acción requiere iniciar sesión.');
    }

    if (requiredTrustLevel !== undefined && actor.trustLevel < requiredTrustLevel) {
      throw new BusinessRuleViolation(
        'nivel_de_confianza_insuficiente',
        `Para hacer esto necesitas nivel ${requiredTrustLevel} de confianza.`,
        'forbidden',
        { nivelActual: actor.trustLevel, nivelRequerido: requiredTrustLevel },
      );
    }

    if (requiredRoles?.length && !requiredRoles.some((role) => actor.roles.includes(role))) {
      throw new BusinessRuleViolation(
        'rol_requerido',
        `Para hacer esto necesitas uno de estos roles: ${requiredRoles.join(', ')}.`,
        'forbidden',
        { rolesRequeridos: requiredRoles },
      );
    }

    return true;
  }
}
