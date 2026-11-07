import { copyFile, mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { unzipSync } from "fflate";
import { cdnRoot, district, publicRoot } from "./config.mjs";

const cache = join(
  cdnRoot,
  ".cache",
  `basemaps-assets-${district.assetsCommit}.zip`,
);
await mkdir(dirname(cache), { recursive: true });
let archive;
try {
  archive = await readFile(cache);
} catch (error) {
  if (error.code !== "ENOENT") throw error;
  const url = `https://codeload.github.com/protomaps/basemaps-assets/zip/${district.assetsCommit}`;
  const response = await fetch(url, { signal: AbortSignal.timeout(120_000) });
  if (!response.ok)
    throw new Error(
      `No se pudieron descargar los recursos: HTTP ${response.status}`,
    );
  archive = new Uint8Array(await response.arrayBuffer());
  await writeFile(cache, archive);
}

const prefix = `basemaps-assets-${district.assetsCommit}/`;
const selected = (name) =>
  name.startsWith(prefix) &&
  (/^fonts\/(?:[^/]+\/\d+-\d+\.pbf|OFL\.txt)$/.test(
    name.slice(prefix.length),
  ) ||
    /^sprites\/v4\/light(?:@2x)?\.(?:json|png)$/.test(
      name.slice(prefix.length),
    ));
const files = unzipSync(archive, { filter: (entry) => selected(entry.name) });
let count = 0;
for (const [name, data] of Object.entries(files)) {
  const source = name.slice(prefix.length);
  const target = source.startsWith("fonts/")
    ? source.replace("fonts/", "fuentes/")
    : source.replace("sprites/v4/", "sprites/");
  const destination = join(publicRoot, target);
  await mkdir(dirname(destination), { recursive: true });
  await writeFile(destination, data);
  count++;
}
if (count === 0)
  throw new Error(
    "El archivo de recursos no contiene las fuentes y sprites esperados.",
  );

await mkdir(join(publicRoot, "vendor"), { recursive: true });
for (const file of [
  "maplibre-gl.mjs",
  "maplibre-gl-worker.mjs",
  "maplibre-gl-shared.mjs",
  "maplibre-gl.css",
]) {
  await copyFile(
    join(cdnRoot, "node_modules/maplibre-gl/dist", file),
    join(publicRoot, "vendor", file),
  );
}
await copyFile(
  join(cdnRoot, "node_modules/maplibre-gl/LICENSE.txt"),
  join(publicRoot, "vendor/LICENSE.txt"),
);
console.log(
  `Recursos locales generados: ${count} archivos de fuentes/sprites y MapLibre GL JS.`,
);
