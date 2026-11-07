import { mkdir, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { layers, namedFlavor } from "@protomaps/basemaps";
import { district, publicBaseUrl, publicRoot } from "./config.mjs";

export function createStyle(baseUrl) {
  const origin = publicBaseUrl(baseUrl);
  return {
    version: 8,
    name: "Vecinal · mapa claro en español",
    metadata: {
      "vecinal:district": district.id,
      "vecinal:source-version": district.sourceVersion,
    },
    center: district.center,
    zoom: 13,
    glyphs: `${origin}/fuentes/{fontstack}/{range}.pbf`,
    sprite: `${origin}/sprites/light`,
    sources: {
      vecinal: {
        type: "vector",
        tiles: [`${origin}/teselas/{z}/{x}/{y}.mvt`],
        bounds: district.bounds,
        minzoom: 0,
        maxzoom: district.maxZoom,
        attribution:
          '<a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener">© OpenStreetMap contributors</a> · ' +
          '<a href="https://esa-worldcover.org/en/data-access" target="_blank" rel="noopener">ESA WorldCover</a> ' +
          '(<a href="https://creativecommons.org/licenses/by/4.0/" target="_blank" rel="noopener">CC BY 4.0</a>)',
      },
    },
    layers: layers("vecinal", namedFlavor("light"), { lang: "es" }),
  };
}

export async function buildStyle() {
  const style = createStyle(process.env.MAP_PUBLIC_URL);
  await mkdir(resolve(publicRoot, "estilos"), { recursive: true });
  await writeFile(
    resolve(publicRoot, "estilos/vecinal.json"),
    `${JSON.stringify(style, null, 2)}\n`,
  );
  console.log(`Estilo generado: ${style.sources.vecinal.tiles[0]}`);
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(resolve(process.argv[1])).href
) {
  await buildStyle();
}
