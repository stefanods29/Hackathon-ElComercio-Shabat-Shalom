import assert from "node:assert/strict";
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";
import {
  buildEmergencyIndex,
  emergencyConfigPath,
  emergencyDirectory,
  emergencyIndexPath,
  serializeIndex,
} from "../scripts/build-emergency-index.mjs";

const schemaPath = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../../../contracts/directorio-emergencia.schema.json",
);

async function validators() {
  // strictRequired would reject `required` inside `then`, which is valid JSON Schema.
  const ajv = new Ajv2020({
    allErrors: true,
    strict: true,
    strictRequired: false,
  });
  addFormats(ajv);
  ajv.addSchema(JSON.parse(await readFile(schemaPath, "utf8")), "directorio");
  return {
    district: ajv.getSchema("directorio"),
    index: ajv.getSchema("directorio#/$defs/indice"),
  };
}

const json = async (file) => JSON.parse(await readFile(file, "utf8"));

const appBackupPath = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../../../app/assets/emergencia/respaldo.json",
);

test("cada distrito publicado cumple el contrato del directorio de emergencia", async () => {
  const { district } = await validators();
  const config = await json(emergencyConfigPath);
  for (const entry of config.distritos) {
    const directory = await json(path.join(emergencyDirectory, entry.archivo));
    assert.equal(
      district(directory),
      true,
      JSON.stringify(district.errors, null, 2),
    );
  }
});

test("una entrada sin fuente o un número sin teléfono no cumplen el contrato", async () => {
  const { district } = await validators();
  const base = {
    version: 1,
    distrito: "Prueba",
    generadoEn: "2026-11-07T12:00:00Z",
  };
  const noSource = {
    id: "punto-a",
    tipo: "punto_de_encuentro",
    nombre: "Punto de prueba",
    ubicacion: { lat: -12.08, lng: -77.03 },
    verificadoEn: "2026-11-07",
  };
  const noPhone = {
    id: "numero-a",
    tipo: "numero",
    nombre: "Número de prueba",
    fuente: { nombre: "Fuente de prueba" },
    verificadoEn: "2026-11-07",
  };
  assert.equal(district({ ...base, entradas: [noSource] }), false);
  assert.equal(district({ ...base, entradas: [noPhone] }), false);
});

test("el índice publicado coincide con los archivos y cumple su contrato", async () => {
  const { index } = await validators();
  const published = await json(emergencyIndexPath);
  assert.equal(index(published), true, JSON.stringify(index.errors, null, 2));
  assert.equal(
    serializeIndex(published),
    serializeIndex(await buildEmergencyIndex()),
    "Ejecuta `npm run emergencia:indice` después de cambiar un distrito.",
  );
});

test("no hay archivos de distrito fuera del índice", async () => {
  const config = await json(emergencyConfigPath);
  const listed = new Set(config.distritos.map((entry) => entry.archivo));
  const files = (await readdir(emergencyDirectory)).filter(
    (file) => file.endsWith(".json") && file !== "indice.json",
  );
  assert.deepEqual(
    files.filter((file) => !listed.has(file)),
    [],
  );
});

test("la copia de respaldo de la app cumple el mismo contrato", async () => {
  const { district } = await validators();
  const backup = await json(appBackupPath);
  assert.equal(
    district(backup),
    true,
    JSON.stringify(district.errors, null, 2),
  );
  assert.deepEqual(
    backup.entradas.map((entry) => entry.telefono),
    ["116", "105", "106"],
  );
});
