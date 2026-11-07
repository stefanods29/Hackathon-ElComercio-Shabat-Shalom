import { type KeyObject, createPrivateKey, createPublicKey } from 'node:crypto';
import { Inject, Injectable } from '@nestjs/common';
import { type JWK, type JWTPayload, SignJWT, jwtVerify } from 'jose';
import { APP_CONFIG, type AppConfig } from '../config/app-config.js';
import { CLOCK, type Clock } from '../domain/clock.js';
import { newId } from '../domain/ids.js';
import { type Actor, ROLES, type Role } from './actor.js';

/** Audience of the tokens for the REST API. */
export const API_AUDIENCE = 'vecinal-api';
/** Audience of the tokens the phone presents to the PowerSync service. */
export const POWERSYNC_AUDIENCE = 'powersync';

export interface IssuedToken {
  readonly token: string;
  readonly expiresAt: Date;
}

export class InvalidToken extends Error {
  constructor(reason: string) {
    super(reason);
    this.name = 'InvalidToken';
  }
}

function actorFromClaims(claims: JWTPayload): Actor {
  const { sub, zona, nivel, roles } = claims as JWTPayload & {
    zona?: unknown;
    nivel?: unknown;
    roles?: unknown;
  };
  if (typeof sub !== 'string' || sub.length === 0) throw new InvalidToken('Falta el sujeto (sub)');
  if (typeof nivel !== 'number' || !Number.isInteger(nivel) || nivel < 0 || nivel > 3) {
    throw new InvalidToken('Nivel de confianza inválido');
  }
  const validRoles = Array.isArray(roles)
    ? roles.filter((role): role is Role => (ROLES as readonly unknown[]).includes(role))
    : [];
  return {
    id: sub,
    zoneId: typeof zona === 'string' ? zona : null,
    trustLevel: nivel,
    roles: validRoles,
  };
}

/**
 * Signs and verifies ES256 JWTs. The public key is published as JWKS at
 * `/.well-known/jwks.json` so PowerSync can validate the sync tokens.
 */
@Injectable()
export class TokenService {
  private readonly privateKey: KeyObject;
  private readonly publicKey: KeyObject;
  private readonly publicJwk: JWK;

  constructor(
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {
    this.privateKey = createPrivateKey(config.JWT_PRIVATE_KEY_PEM);
    if (
      this.privateKey.asymmetricKeyType !== 'ec' ||
      this.privateKey.asymmetricKeyDetails?.namedCurve !== 'prime256v1'
    ) {
      throw new Error('JWT_PRIVATE_KEY_PEM debe ser una clave EC P-256 (ES256)');
    }
    this.publicKey = createPublicKey(this.privateKey);
    this.publicJwk = {
      ...(this.publicKey.export({ format: 'jwk' }) as JWK),
      kid: config.JWT_KID,
      alg: 'ES256',
      use: 'sig',
    };
  }

  jwks(): { keys: JWK[] } {
    return { keys: [this.publicJwk] };
  }

  issueAccess(actor: Actor): Promise<IssuedToken> {
    return this.sign(actor, API_AUDIENCE, this.config.JWT_ACCESS_MINUTES);
  }

  issueSync(actor: Actor): Promise<IssuedToken> {
    return this.sign(actor, POWERSYNC_AUDIENCE, this.config.JWT_SYNC_MINUTES);
  }

  async verifyAccess(token: string): Promise<Actor> {
    return this.verify(token, API_AUDIENCE);
  }

  async verify(token: string, audience: string): Promise<Actor> {
    try {
      const { payload } = await jwtVerify(token, this.publicKey, {
        issuer: this.config.JWT_ISSUER,
        audience,
        algorithms: ['ES256'],
        currentDate: this.clock.now(),
      });
      return actorFromClaims(payload);
    } catch (error) {
      if (error instanceof InvalidToken) throw error;
      throw new InvalidToken(error instanceof Error ? error.message : 'Token inválido');
    }
  }

  private async sign(actor: Actor, audience: string, minutes: number): Promise<IssuedToken> {
    const issuedAt = Math.floor(this.clock.now().getTime() / 1000);
    const expiresAt = issuedAt + minutes * 60;
    // Claim names are part of the contract with PowerSync (`auth.parameter('zona')`).
    const token = await new SignJWT({
      zona: actor.zoneId,
      nivel: actor.trustLevel,
      roles: actor.roles,
    })
      .setProtectedHeader({ alg: 'ES256', kid: this.config.JWT_KID, typ: 'JWT' })
      .setIssuer(this.config.JWT_ISSUER)
      .setAudience(audience)
      .setSubject(actor.id)
      .setIssuedAt(issuedAt)
      .setExpirationTime(expiresAt)
      .setJti(newId())
      .sign(this.privateKey);
    return { token, expiresAt: new Date(expiresAt * 1000) };
  }
}
