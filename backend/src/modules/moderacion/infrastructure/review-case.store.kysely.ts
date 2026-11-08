import { Injectable } from '@nestjs/common';
import { sql } from 'kysely';
import type { TransactionContext } from '../../../shared/db/unit-of-work.js';
import { asKysely } from '../../../shared/db/unit-of-work.kysely.js';
import type { ReviewCaseStore } from '../application/ports.js';

@Injectable()
export class KyselyReviewCaseStore implements ReviewCaseStore {
  async openReviewPatternCase(
    transaction: TransactionContext,
    reviewId: string,
    now: Date,
  ): Promise<void> {
    await sql`
      INSERT INTO moderacion.casos (tipo_contenido, contenido_id, estado, motivo, creado_en, actualizado_en)
      VALUES ('resena', ${reviewId}, 'pendiente', 'patron_de_resenas', ${now}, ${now})
      ON CONFLICT (tipo_contenido, contenido_id) DO NOTHING
    `.execute(asKysely(transaction));
  }
}
