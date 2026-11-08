import { Inject, Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { type Kysely, sql } from 'kysely';
import { KYSELY } from '../../../shared/db/connection.js';
import { BusinessRuleViolation, ResourceNotFound } from '../../../shared/domain/errors.js';
import type { PhotoClaim, PhotoRepository, ProcessedPhoto } from '../application/ports.js';
import {
  MAX_PROCESSING_ATTEMPTS,
  PHOTO_LEASE_SECONDS,
  samePhoto,
  type Photo,
} from '../domain/photo.js';

interface PhotoRow {
  id: string;
  propietario_id: string;
  zona_id: string;
  tipo_contenido: Photo['contentType'];
  bytes: number;
  sha256: string;
  estado: Photo['state'];
  creado_en: Date;
  ancho: number | null;
  alto: number | null;
  blurhash: string | null;
  motivo: string | null;
  version_procesada: string | null;
}
function fromRow(row: PhotoRow): Photo {
  return {
    id: row.id,
    ownerId: row.propietario_id,
    zoneId: row.zona_id,
    contentType: row.tipo_contenido,
    bytes: row.bytes,
    sha256: row.sha256,
    state: row.estado,
    createdAt: row.creado_en,
    width: row.ancho,
    height: row.alto,
    blurhash: row.blurhash,
    failure: row.motivo,
    processedVersion: row.version_procesada,
  };
}

@Injectable()
export class PostgresPhotoRepository implements PhotoRepository {
  constructor(@Inject(KYSELY) private readonly db: Kysely<unknown>) {}

  async reserve(photo: Photo): Promise<Photo> {
    return this.db.transaction().execute(async (trx) => {
      // Serialize each owner's quota checks; parallel reservations cannot exceed the limit.
      await sql`SELECT pg_advisory_xact_lock(hashtextextended(${photo.ownerId}, 0))`.execute(trx);
      const existing =
        await sql<PhotoRow>`SELECT * FROM media.archivos WHERE id = ${photo.id}::uuid`.execute(trx);
      if (existing.rows[0]) {
        const saved = fromRow(existing.rows[0]);
        if (saved.ownerId !== photo.ownerId || saved.state === 'eliminado')
          throw new ResourceNotFound('el archivo', photo.id);
        if (!samePhoto(saved, photo))
          throw new BusinessRuleViolation(
            'archivo_distinto',
            'Ese identificador ya corresponde a otra foto.',
            'conflict',
          );
        return saved;
      }
      const count = await sql<{ total: number }>`SELECT count(*)::int AS total FROM media.archivos
        WHERE propietario_id = ${photo.ownerId}::uuid AND creado_en > now() - interval '24 hours'`.execute(
        trx,
      );
      if ((count.rows[0]?.total ?? 0) >= 20)
        throw new BusinessRuleViolation(
          'limite_de_fotos',
          'Alcanzaste el límite de 20 fotos por día. Puedes intentarlo mañana.',
        );
      const inserted =
        await sql<PhotoRow>`INSERT INTO media.archivos(id, propietario_id, zona_id, tipo_contenido, bytes, sha256)
        VALUES (${photo.id}::uuid, ${photo.ownerId}::uuid, ${photo.zoneId}::uuid, ${photo.contentType}, ${photo.bytes}, ${photo.sha256})
        ON CONFLICT DO NOTHING RETURNING *`.execute(trx);
      if (!inserted.rows[0]) throw new ResourceNotFound('el archivo', photo.id);
      return fromRow(inserted.rows[0]);
    });
  }
  async findOwned(id: string, ownerId: string): Promise<Photo | null> {
    const result =
      await sql<PhotoRow>`SELECT * FROM media.archivos WHERE id = ${id}::uuid AND propietario_id = ${ownerId}::uuid`.execute(
        this.db,
      );
    return result.rows[0] ? fromRow(result.rows[0]) : null;
  }
  async allowUploadUntil(id: string, ownerId: string, expiresAt: Date): Promise<boolean> {
    const result =
      await sql`UPDATE media.archivos SET subida_hasta = greatest(subida_hasta, ${expiresAt}), actualizado_en = now()
      WHERE id = ${id}::uuid AND propietario_id = ${ownerId}::uuid AND estado = 'pendiente_subida'
      AND creado_en > now() - interval '24 hours' RETURNING id`.execute(this.db);
    return result.rows.length > 0;
  }
  async enqueue(id: string, ownerId: string): Promise<void> {
    await sql`UPDATE media.archivos SET estado = 'en_cola', actualizado_en = now()
      WHERE id = ${id}::uuid AND propietario_id = ${ownerId}::uuid AND estado = 'pendiente_subida'`.execute(
      this.db,
    );
  }
  async remove(id: string, ownerId: string): Promise<void> {
    await sql`UPDATE media.archivos SET estado = 'eliminado', actualizado_en = now(), limpiado_en = NULL,
      limpiar_despues = greatest(subida_hasta, arrendado_hasta, now()), arrendamiento_id = NULL
      WHERE id = ${id}::uuid AND propietario_id = ${ownerId}::uuid AND estado <> 'eliminado'`.execute(
      this.db,
    );
  }
  async claim(): Promise<PhotoClaim | null> {
    const leaseId = randomUUID();
    const result = await sql<PhotoRow>`WITH siguiente AS (
      SELECT id FROM media.archivos WHERE disponible_en <= now() AND
        (estado = 'en_cola' OR (estado = 'procesando' AND arrendado_hasta < now()))
        AND intentos < ${MAX_PROCESSING_ATTEMPTS} ORDER BY creado_en FOR UPDATE SKIP LOCKED LIMIT 1
      ) UPDATE media.archivos SET estado = 'procesando', intentos = intentos + 1,
        arrendamiento_id = ${leaseId}::uuid, arrendado_hasta = now() + ${PHOTO_LEASE_SECONDS} * interval '1 second',
        actualizado_en = now() WHERE id IN (SELECT id FROM siguiente) RETURNING *`.execute(this.db);
    // An interrupted last attempt must also reach a terminal state rather than remain stuck.
    await sql`UPDATE media.archivos SET estado = 'rechazado', motivo = 'error_de_procesamiento',
      limpiar_despues = greatest(subida_hasta, now()), actualizado_en = now()
      WHERE estado = 'procesando' AND arrendado_hasta < now() AND intentos >= ${MAX_PROCESSING_ATTEMPTS}`.execute(
      this.db,
    );
    return result.rows[0] ? { photo: fromRow(result.rows[0]), leaseId } : null;
  }
  async finish(claim: PhotoClaim, result: ProcessedPhoto): Promise<boolean> {
    const saved =
      await sql`UPDATE media.archivos SET estado = 'listo', ancho = ${result.width}, alto = ${result.height},
      blurhash = ${result.blurhash}, version_procesada = ${claim.leaseId}::uuid, motivo = NULL, actualizado_en = now(),
      limpiar_despues = greatest(subida_hasta, now()), arrendado_hasta = NULL
      WHERE id = ${claim.photo.id}::uuid AND arrendamiento_id = ${claim.leaseId}::uuid AND estado = 'procesando' RETURNING id`.execute(
        this.db,
      );
    return saved.rows.length > 0;
  }
  async fail(claim: PhotoClaim, reason: string, permanent: boolean): Promise<void> {
    await sql`UPDATE media.archivos SET estado = CASE WHEN ${permanent} OR intentos >= ${MAX_PROCESSING_ATTEMPTS}
        THEN 'rechazado' ELSE 'en_cola' END, motivo = ${reason}, actualizado_en = now(),
      disponible_en = now() + (power(2, intentos) * 10) * interval '1 second',
      limpiar_despues = CASE WHEN ${permanent} OR intentos >= ${MAX_PROCESSING_ATTEMPTS}
        THEN greatest(subida_hasta, now()) ELSE NULL END, arrendado_hasta = NULL
      WHERE id = ${claim.photo.id}::uuid AND arrendamiento_id = ${claim.leaseId}::uuid AND estado = 'procesando'`.execute(
      this.db,
    );
  }
  async claimCleanup(): Promise<PhotoClaim | null> {
    await sql`UPDATE media.archivos SET estado = 'eliminado', limpiar_despues = greatest(subida_hasta, now())
      WHERE estado = 'pendiente_subida' AND creado_en < now() - interval '24 hours'`.execute(
      this.db,
    );
    const leaseId = randomUUID();
    const result = await sql<PhotoRow>`WITH siguiente AS (
      SELECT id FROM media.archivos WHERE estado IN ('listo','rechazado','eliminado') AND limpiado_en IS NULL
      AND limpiar_despues <= now() AND (arrendado_hasta IS NULL OR arrendado_hasta < now())
      ORDER BY limpiar_despues FOR UPDATE SKIP LOCKED LIMIT 1
    ) UPDATE media.archivos SET arrendamiento_id = ${leaseId}::uuid,
      arrendado_hasta = now() + ${PHOTO_LEASE_SECONDS} * interval '1 second'
      WHERE id IN (SELECT id FROM siguiente) RETURNING *`.execute(this.db);
    return result.rows[0] ? { photo: fromRow(result.rows[0]), leaseId } : null;
  }
  async finishCleanup(claim: PhotoClaim): Promise<void> {
    await sql`UPDATE media.archivos SET limpiado_en = now(), arrendado_hasta = NULL
      WHERE id = ${claim.photo.id}::uuid AND arrendamiento_id = ${claim.leaseId}::uuid`.execute(
      this.db,
    );
  }
}
