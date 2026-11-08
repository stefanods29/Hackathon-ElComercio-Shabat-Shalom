import { createHash } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import { asKysely } from '../../../shared/db/unit-of-work.kysely.js';
import type { ReviewerContext, ReviewerReader } from '../application/reviewer-reader.js';
import type { IdentityTables } from './tables.js';

@Injectable()
export class KyselyReviewerReader implements ReviewerReader {
  async findReviewer(
    transaction: TransactionContext,
    userId: string,
    sessionId?: string,
  ): Promise<ReviewerContext | null> {
    const db = asKysely<IdentityTables>(transaction);
    const user = await db
      .selectFrom('identidad.usuarios')
      .select('creado_en')
      .where('id', '=', userId)
      .where('eliminado_en', 'is', null)
      .executeTakeFirst();
    if (!user) return null;
    const session = sessionId
      ? await db
          .selectFrom('identidad.sesiones')
          .select('dispositivo')
          .where('usuario_id', '=', userId)
          .where('familia_id', '=', sessionId)
          .orderBy('creada_en', 'desc')
          .orderBy('id', 'desc')
          .executeTakeFirst()
      : undefined;
    const device = session?.dispositivo?.trim();
    return {
      createdAt: user.creado_en,
      deviceHash: device ? createHash('sha256').update(device).digest('hex') : null,
    };
  }
}
