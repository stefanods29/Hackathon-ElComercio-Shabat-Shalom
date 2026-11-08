import { Inject, Injectable, ServiceUnavailableException } from '@nestjs/common';
import { createHash } from 'node:crypto';
import type { Actor } from '../../../shared/auth/actor.js';
import { UNIT_OF_WORK, type UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { CLOCK, type Clock } from '../../../shared/domain/clock.js';
import {
  BusinessRuleViolation,
  ResourceNotFound,
  VersionConflict,
} from '../../../shared/domain/errors.js';
import {
  type DirectoryProblem,
  type EmergencyDirectory,
  type EmergencyIndex,
  type IndexEntry,
  findDirectoryProblems,
  limaDate,
  serializePublicJson,
  withPublishedDistrict,
} from '../domain/emergency-directory.js';
import { directorySchema, indexSchema, publicationSchema } from './directory-schema.js';
import {
  DIRECTORY_VERSIONS,
  PUBLIC_CONTENT_PUBLISHER,
  type DirectoryVersionStore,
  type PublicContentPublisher,
} from './ports.js';

const INDEX_PATH = 'emergencia/indice.json';
const JSON_TYPE = 'application/json';

export interface PublishedDirectoryDto {
  readonly archivo: string;
  readonly sha256: string;
  readonly bytes: number;
  readonly directorio: EmergencyDirectory;
}

function sha256(body: Buffer): string {
  return createHash('sha256').update(body).digest('hex');
}

function invalidDirectory(problems: readonly DirectoryProblem[]): BusinessRuleViolation {
  return new BusinessRuleViolation(
    'directorio_invalido',
    'El directorio tiene datos que no cumplen el formato. Revisa cada campo marcado.',
    'invalid',
    { errores: problems.map((problem) => ({ campo: problem.field, mensaje: problem.message })) },
  );
}

/**
 * Curation of the emergency directory from the console (Phase 2, Lot C, part 3). Replaces the
 * Phase 1 edit-by-PR: every version is validated, audited and published with its index.
 */
@Injectable()
export class EmergencyDirectories {
  constructor(
    @Inject(PUBLIC_CONTENT_PUBLISHER) private readonly publisher: PublicContentPublisher,
    @Inject(DIRECTORY_VERSIONS) private readonly versions: DirectoryVersionStore,
    @Inject(UNIT_OF_WORK) private readonly unitOfWork: UnitOfWork,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  async list(): Promise<{ datos: readonly IndexEntry[] }> {
    const index = await this.readIndex();
    return { datos: index.distritos };
  }

  async get(archivo: string): Promise<PublishedDirectoryDto> {
    const index = await this.readIndex();
    if (!index.distritos.some((district) => district.archivo === archivo)) {
      throw new ResourceNotFound('directorio de emergencia', archivo);
    }
    const body = await this.publisher.read(`emergencia/${archivo}`);
    if (!body) throw new ResourceNotFound('directorio de emergencia', archivo);
    const directory = directorySchema.parse(JSON.parse(body.toString('utf8')));
    return { archivo, sha256: sha256(body), bytes: body.length, directorio: directory };
  }

  async publish(actor: Actor, archivo: string, input: unknown): Promise<PublishedDirectoryDto> {
    const parsed = publicationSchema.safeParse(input);
    if (!parsed.success) {
      throw invalidDirectory(
        parsed.error.issues.map((issue) => ({
          field: issue.path.map(String).join('.') || 'cuerpo',
          message: issue.message,
        })),
      );
    }
    const now = this.clock.now();
    const problems = findDirectoryProblems(parsed.data.entradas, limaDate(now));
    if (problems.length > 0) throw invalidDirectory(problems);

    return this.unitOfWork.run(async (transaction) => {
      await this.versions.lock(transaction, archivo);
      const index = await this.readIndex();
      const district = index.distritos.find((entry) => entry.archivo === archivo);
      if (!district) throw new ResourceNotFound('directorio de emergencia', archivo);
      // The CDN file may come from the Phase 1 PR flow, before any version was recorded here.
      const current = Math.max(district.version, (await this.versions.latest(transaction, archivo)) ?? 0);
      if (parsed.data.versionVista !== current) {
        throw new VersionConflict(parsed.data.versionVista, current);
      }
      const directory: EmergencyDirectory = {
        version: current + 1,
        distrito: parsed.data.distrito,
        generadoEn: now.toISOString(),
        entradas: parsed.data.entradas,
      };
      const body = Buffer.from(serializePublicJson(directory), 'utf8');
      const digest = sha256(body);
      await this.versions.insert(transaction, {
        archivo,
        version: directory.version,
        contenido: directory,
        sha256: digest,
        bytes: body.length,
        publicadoPor: actor.id,
        publicadoEn: now,
      });
      // Written inside the transaction: if the CDN write fails, the version is not recorded.
      await this.publisher.write(`emergencia/${archivo}`, body, JSON_TYPE);
      const nextIndex = withPublishedDistrict(
        index,
        archivo,
        { version: directory.version, sha256: digest, bytes: body.length },
        directory.generadoEn,
      );
      await this.publisher.write(
        INDEX_PATH,
        Buffer.from(serializePublicJson(nextIndex), 'utf8'),
        JSON_TYPE,
      );
      return { archivo, sha256: digest, bytes: body.length, directorio: directory };
    });
  }

  private async readIndex(): Promise<EmergencyIndex> {
    if (!this.publisher.enabled) {
      throw new ServiceUnavailableException(
        'La publicación del directorio de emergencia no está habilitada en este entorno.',
      );
    }
    const body = await this.publisher.read(INDEX_PATH);
    if (!body) {
      throw new ServiceUnavailableException('No se encontró el índice del directorio de emergencia.');
    }
    return indexSchema.parse(JSON.parse(body.toString('utf8')));
  }
}
