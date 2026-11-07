import { Controller, Get, Header } from '@nestjs/common';
import type { JWK } from 'jose';
import { Public } from './decorators.js';
import { TokenService } from './token.service.js';

/** Public keys to validate the JWTs (PowerSync reads them through `jwks_uri`). */
@Controller('.well-known')
@Public()
export class JwksController {
  constructor(private readonly tokens: TokenService) {}

  @Get('jwks.json')
  @Header('cache-control', 'public, max-age=300')
  jwks(): { keys: JWK[] } {
    return this.tokens.jwks();
  }
}
