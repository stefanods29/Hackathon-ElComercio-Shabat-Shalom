import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";

export const cdnRoot = fileURLToPath(new URL("../", import.meta.url));
export const publicRoot = fileURLToPath(
  new URL("../publico/", import.meta.url),
);
export const district = JSON.parse(
  await readFile(new URL("../district.config.json", import.meta.url), "utf8"),
);

export function publicBaseUrl(value = "http://10.0.2.2:8090") {
  const url = new URL(value);
  if (
    !["http:", "https:"].includes(url.protocol) ||
    url.username ||
    url.password ||
    url.search ||
    url.hash ||
    url.pathname !== "/"
  ) {
    throw new Error(
      "MAP_PUBLIC_URL debe ser un origen HTTP(S), sin ruta ni credenciales.",
    );
  }
  return url.origin;
}
