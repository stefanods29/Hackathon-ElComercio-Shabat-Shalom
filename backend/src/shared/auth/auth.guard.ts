import {
  type CanActivate,
  type ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthenticationFailure } from '../domain/errors.js';
import { AccountAccess } from './account-access.js';
import type { Actor, AuthenticatedRequest } from './actor.js';
import { PUBLIC_METADATA } from './decorators.js';
import { TokenService } from './token.service.js';

/** Global guard: requires `Authorization: Bearer <token>` except on routes marked `@Public()`. */
@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly tokens: TokenService,
    private readonly accounts: AccountAccess,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean | undefined>(PUBLIC_METADATA, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic || context.getType() !== 'http') {
      return true;
    }
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const [scheme, token] = (request.header('authorization') ?? '').split(' ');
    if (scheme?.toLowerCase() !== 'bearer' || !token) {
      throw new UnauthorizedException('Falta el token de acceso.');
    }
    let claims: Actor;
    try {
      claims = await this.tokens.verifyAccess(token);
    } catch {
      throw new UnauthorizedException('El token de acceso no es válido o ya venció.');
    }
    const actor = await this.accounts.resolve(claims);
    if (!actor) throw new AuthenticationFailure('sesion_revocada', 'La cuenta ya no está activa.');
    request.actor = actor;
    return true;
  }
}
