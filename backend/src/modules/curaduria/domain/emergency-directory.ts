/**
 * Emergency directory published on the CDN (Phase 1, Lot A, part 2): only institutional data,
 * never neighbors. The JSON Schema in `contracts/directorio-emergencia.schema.json` is the contract.
 */
export type EntryType = 'numero' | 'punto_de_encuentro' | 'centro_de_salud' | 'albergue';

export interface DirectoryEntry {
  readonly id: string;
  readonly tipo: EntryType;
  readonly nombre: string;
  readonly telefono?: string;
  readonly ubicacion?: { readonly lat: number; readonly lng: number };
  readonly direccion?: string;
  readonly descripcion?: string;
  readonly fuente: { readonly nombre: string; readonly url?: string };
  /** Last day the curator checked the entry against its source (YYYY-MM-DD). */
  readonly verificadoEn: string;
}

export interface EmergencyDirectory {
  readonly version: number;
  readonly distrito: string;
  readonly generadoEn: string;
  readonly entradas: readonly DirectoryEntry[];
}

export interface IndexEntry {
  readonly id: string;
  readonly archivo: string;
  readonly version: number;
  readonly sha256: string;
  readonly bytes: number;
  readonly zonas: readonly string[];
}

export interface EmergencyIndex {
  readonly version: number;
  readonly generadoEn: string;
  readonly distritos: readonly IndexEntry[];
}

export interface DirectoryProblem {
  readonly field: string;
  readonly message: string;
}

/** YYYY-MM-DD of an instant in America/Lima, the pilot's calendar. */
export function limaDate(at: Date): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/Lima',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(at);
}

/** Rules the JSON Schema cannot express: unique ids and no verification in the future. */
export function findDirectoryProblems(
  entries: readonly DirectoryEntry[],
  today: string,
): DirectoryProblem[] {
  const problems: DirectoryProblem[] = [];
  const seen = new Set<string>();
  entries.forEach((entry, position) => {
    if (seen.has(entry.id)) {
      problems.push({
        field: `entradas.${position}.id`,
        message: 'Ya hay otra entrada con este identificador.',
      });
    }
    seen.add(entry.id);
    // ISO dates compare correctly as text.
    if (entry.verificadoEn > today) {
      problems.push({
        field: `entradas.${position}.verificadoEn`,
        message: 'La fecha de verificación no puede estar en el futuro.',
      });
    }
  });
  return problems;
}

/** Same layout as `infra/cdn/scripts/build-emergency-index.mjs`: zones never change here. */
export function withPublishedDistrict(
  index: EmergencyIndex,
  archivo: string,
  published: { readonly version: number; readonly sha256: string; readonly bytes: number },
  generatedAt: string,
): EmergencyIndex {
  return {
    version: index.version,
    generadoEn: generatedAt,
    distritos: index.distritos.map((district) =>
      district.archivo === archivo
        ? {
            id: district.id,
            archivo: district.archivo,
            version: published.version,
            sha256: published.sha256,
            bytes: published.bytes,
            zonas: district.zonas,
          }
        : district,
    ),
  };
}

/** Byte layout of every published file: two-space JSON and a final newline, like the scripts. */
export function serializePublicJson(value: unknown): string {
  return `${JSON.stringify(value, null, 2)}\n`;
}
