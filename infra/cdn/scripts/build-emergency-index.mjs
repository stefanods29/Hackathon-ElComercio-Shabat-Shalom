// Recalcula publico/emergencia/indice.json a partir de emergencia.config.json y de los archivos
// de cada distrito: versión, SHA-256, tamaño y zonas. Uso: `npm run emergencia:indice`.
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
export const emergencyDirectory = path.join(root, "publico", "emergencia");
export const emergencyConfigPath = path.join(root, "emergencia.config.json");
export const emergencyIndexPath = path.join(emergencyDirectory, "indice.json");

/** Builds the index deterministically: `generadoEn` is the newest district date. */
export async function buildEmergencyIndex() {
  const config = JSON.parse(await readFile(emergencyConfigPath, "utf8"));
  const districts = [];
  for (const entry of config.distritos) {
    const bytes = await readFile(path.join(emergencyDirectory, entry.archivo));
    const directory = JSON.parse(bytes.toString("utf8"));
    districts.push({
      id: entry.id,
      archivo: entry.archivo,
      version: directory.version,
      sha256: createHash("sha256").update(bytes).digest("hex"),
      bytes: bytes.length,
      zonas: entry.zonas,
      generadoEn: directory.generadoEn,
    });
  }
  const newest = districts
    .map((district) => district.generadoEn)
    .sort()
    .at(-1);
  return {
    version: 1,
    generadoEn: newest,
    distritos: districts.map(
      ({ generadoEn: _generatedAt, ...district }) => district,
    ),
  };
}

export function serializeIndex(index) {
  return `${JSON.stringify(index, null, 2)}\n`;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const index = await buildEmergencyIndex();
  await writeFile(emergencyIndexPath, serializeIndex(index));
  console.log(
    `Índice del directorio de emergencia: ${index.distritos.length} distrito(s).`,
  );
}
