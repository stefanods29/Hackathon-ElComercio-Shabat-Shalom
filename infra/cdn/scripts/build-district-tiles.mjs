import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { createReadStream } from "node:fs";
import { access, mkdir, rename, rm, stat, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { cdnRoot, district, publicRoot } from "./config.mjs";

let executable = process.env.PMTILES_BIN;
if (!executable) {
  const bundled = join(
    cdnRoot,
    ".tools",
    process.platform === "win32" ? "pmtiles.exe" : "pmtiles",
  );
  executable = await access(bundled).then(
    () => bundled,
    () => "pmtiles",
  );
}

function run(args, capture = false) {
  const result = spawnSync(executable, args, {
    encoding: "utf8",
    stdio: capture ? "pipe" : "inherit",
    windowsHide: true,
  });
  if (result.error)
    throw new Error(
      "No se encuentra pmtiles. Instala la versión indicada en infra/cdn/README.md o define PMTILES_BIN.",
      { cause: result.error },
    );
  if (result.status !== 0)
    throw new Error(
      `pmtiles ${args[0]} falló: ${result.stderr ?? result.status}`,
    );
  return result.stdout?.trim();
}

const version = run(["version"], true);
if (version.split(/[ ,]+/)[1] !== district.pmtilesVersion)
  throw new Error(
    `Se requiere pmtiles ${district.pmtilesVersion}; instalado: ${version}`,
  );
await mkdir(publicRoot, { recursive: true });
const output = join(publicRoot, "distrito.pmtiles");
const temporary = join(cdnRoot, ".cache", "distrito.pmtiles");
await mkdir(join(cdnRoot, ".cache"), { recursive: true });
await rm(temporary, { force: true });
try {
  console.log(`Extrayendo ${district.name} desde ${district.sourceUrl}`);
  // Keep overview levels 0–9 too: zoom 10–15 is the mobile download policy, not an archive constraint.
  run([
    "extract",
    district.sourceUrl,
    temporary,
    `--bbox=${district.bounds.join(",")}`,
    `--maxzoom=${district.maxZoom}`,
  ]);
  run(["verify", temporary]);
  const hash = createHash("sha256");
  for await (const chunk of createReadStream(temporary)) hash.update(chunk);
  const bytes = (await stat(temporary)).size;
  const manifest = {
    district,
    cliVersion: version,
    bytes,
    sha256: hash.digest("hex"),
    generatedAt: new Date().toISOString(),
  };
  await rename(temporary, output);
  await writeFile(
    join(publicRoot, "distrito.manifest.json"),
    `${JSON.stringify(manifest, null, 2)}\n`,
  );
  console.log(
    `Mapa generado: ${(bytes / 1024 / 1024).toFixed(2)} MB · SHA-256 ${manifest.sha256}`,
  );
} catch (error) {
  await rm(temporary, { force: true });
  throw error;
}
