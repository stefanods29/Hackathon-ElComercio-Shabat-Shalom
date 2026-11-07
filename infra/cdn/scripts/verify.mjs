import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { access, readFile } from "node:fs/promises";
import { join } from "node:path";
import { validateStyleMin } from "@maplibre/maplibre-gl-style-spec";
import { district, publicBaseUrl, publicRoot } from "./config.mjs";

const style = JSON.parse(
  await readFile(join(publicRoot, "estilos/vecinal.json"), "utf8"),
);
assert.deepEqual(
  validateStyleMin(style).map((error) => error.message),
  [],
  "Estilo MapLibre inválido",
);
const resources = [
  "fuentes/OFL.txt",
  ...[
    "Noto Sans Regular",
    "Noto Sans Medium",
    "Noto Sans Italic",
    "Noto Sans Devanagari Regular v1",
  ].map((font) => `fuentes/${font}/0-255.pbf`),
  "sprites/light.json",
  "sprites/light.png",
  "sprites/light@2x.json",
  "sprites/light@2x.png",
  "vendor/maplibre-gl.mjs",
  "vendor/maplibre-gl-worker.mjs",
  "vendor/maplibre-gl-shared.mjs",
  "vendor/maplibre-gl.css",
  "vendor/LICENSE.txt",
];
for (const resource of resources) await access(join(publicRoot, resource));
console.log("Estilo MapLibre, fuentes, sprites y visor local correctos.");
if (process.argv.includes("--assets-only")) {
  assert.ok(
    !process.argv.includes("--url"),
    "--assets-only no comprueba el servidor ni el mapa",
  );
  process.exit(0);
}

const archive = await readFile(join(publicRoot, "distrito.pmtiles"));
assert.equal(archive.subarray(0, 7).toString(), "PMTiles");
assert.equal(archive[7], 3, "Se requiere un archivo PMTiles v3");
const manifest = JSON.parse(
  await readFile(join(publicRoot, "distrito.manifest.json"), "utf8"),
);
assert.equal(manifest.bytes, archive.length);
assert.equal(
  manifest.sha256,
  createHash("sha256").update(archive).digest("hex"),
);
assert.deepEqual(
  manifest.district,
  district,
  "El mapa se generó con otra configuración",
);
console.log(
  `Archivos, estilo, recursos y SHA-256 correctos. Mapa: ${(archive.length / 1024 / 1024).toFixed(2)} MB.`,
);

if (process.argv.includes("--url")) {
  const urlIndex = process.argv.indexOf("--url");
  assert.ok(process.argv[urlIndex + 1], "Indica el origen después de --url");
  const origin = publicBaseUrl(process.argv[urlIndex + 1]);
  const range = await fetch(`${origin}/distrito.pmtiles`, {
    headers: { Range: "bytes=0-1023" },
    signal: AbortSignal.timeout(15_000),
  });
  assert.equal(range.status, 206, "El servidor debe responder 206 a Range");
  assert.equal(
    range.headers.get("content-range"),
    `bytes 0-1023/${archive.length}`,
  );
  assert.equal(range.headers.get("access-control-allow-origin"), "*");
  assert.deepEqual(
    Buffer.from(await range.arrayBuffer()),
    archive.subarray(0, 1024),
  );

  for (const path of [
    "/visor.html",
    "/visor.js",
    "/estilos/vecinal.json",
    ...resources.map((resource) => `/${resource}`),
  ]) {
    const response = await fetch(`${origin}${path}`, {
      signal: AbortSignal.timeout(15_000),
    });
    assert.equal(response.status, 200, `Recurso inaccesible: ${path}`);
    await response.arrayBuffer();
  }
  const [lng, lat] = district.center;
  const zoom = 14;
  const size = 2 ** zoom;
  const x = Math.floor(((lng + 180) / 360) * size);
  const radians = (lat * Math.PI) / 180;
  const y = Math.floor(
    ((1 - Math.asinh(Math.tan(radians)) / Math.PI) / 2) * size,
  );
  const tile = await fetch(`${origin}/teselas/${zoom}/${x}/${y}.mvt`, {
    signal: AbortSignal.timeout(15_000),
  });
  assert.equal(
    tile.status,
    200,
    "La tesela del centro del distrito no se puede descargar",
  );
  assert.ok((await tile.arrayBuffer()).byteLength > 0, "Tesela vacía");
  console.log(
    `HTTP correcto: Range 206, recursos locales y tesela XYZ ${zoom}/${x}/${y}.`,
  );
}
