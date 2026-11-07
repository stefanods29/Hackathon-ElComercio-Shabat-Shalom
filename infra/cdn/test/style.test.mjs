import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { test } from "node:test";
import { validateStyleMin } from "@maplibre/maplibre-gl-style-spec";
import { createStyle } from "../scripts/build-style.mjs";
import { district, publicBaseUrl } from "../scripts/config.mjs";

test("el estilo es válido para MapLibre y usa XYZ para las regiones offline", () => {
  const style = createStyle("http://localhost:8090");
  assert.deepEqual(
    validateStyleMin(style).map((error) => error.message),
    [],
  );
  assert.deepEqual(style.sources.vecinal.tiles, [
    "http://localhost:8090/teselas/{z}/{x}/{y}.mvt",
  ]);
  assert.ok(
    style.sources.vecinal.attribution.includes("© OpenStreetMap contributors"),
  );
  assert.ok(
    style.sources.vecinal.attribution.includes(
      "https://www.openstreetmap.org/copyright",
    ),
  );
  assert.ok(style.sources.vecinal.attribution.includes("ESA WorldCover"));
  assert.equal(style.sources.vecinal.maxzoom, 15);
});

test("teselas, fuentes e iconos apuntan a nuestro servidor incluso fuera del emulador", () => {
  const style = createStyle("https://mapas.example.test");
  const resources = [
    style.glyphs,
    style.sprite,
    ...style.sources.vecinal.tiles,
  ];
  for (const resource of resources)
    assert.equal(new URL(resource).origin, "https://mapas.example.test");
  assert.ok(!JSON.stringify(style).includes("tile.openstreetmap.org"));
  assert.ok(JSON.stringify(style.layers).includes("name:es"));
});

test("el estilo versionado coincide con el generador predeterminado", async () => {
  const generated = JSON.parse(
    await readFile(
      new URL("../publico/estilos/vecinal.json", import.meta.url),
      "utf8",
    ),
  );
  assert.deepEqual(generated, createStyle());
});

test("el recorte contiene toda la zona piloto y el centro queda dentro de sus límites", () => {
  const [west, south, east, north] = district.bounds;
  assert.ok(
    west <= -77.045 && east >= -77.025 && south <= -12.092 && north >= -12.078,
  );
  assert.ok(district.center[0] >= west && district.center[0] <= east);
  assert.ok(district.center[1] >= south && district.center[1] <= north);
  assert.equal(district.minZoom, 10);
});

test("la URL pública rechaza credenciales, rutas y protocolos que no sirven a MapLibre", () => {
  for (const url of [
    "file:///mapas",
    "https://user:password@example.test",
    "https://example.test/ruta",
    "https://example.test?token=123",
    "https://example.test/#fragment",
  ]) {
    assert.throws(() => publicBaseUrl(url));
  }
  assert.equal(
    publicBaseUrl("https://mapas.example.test/"),
    "https://mapas.example.test",
  );
});
