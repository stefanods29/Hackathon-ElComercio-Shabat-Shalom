import * as maplibregl from "/vendor/maplibre-gl.mjs";
const statusElement = document.getElementById("status");

async function startMap() {
  const response = await fetch("/estilos/vecinal.json");
  if (!response.ok) throw new Error("No se encuentra el estilo del mapa.");
  const style = await response.json();
  // A browser and an Android emulator reach the same CDN through different origins.
  // Preserve MapLibre's {fontstack}/{range}/{z}/{x}/{y} placeholders verbatim.
  const atThisOrigin = (value) =>
    value.replace(new URL(value).origin, window.location.origin);
  style.glyphs = atThisOrigin(style.glyphs);
  style.sprite = atThisOrigin(style.sprite);
  for (const source of Object.values(style.sources))
    source.tiles = source.tiles.map(atThisOrigin);

  const map = new maplibregl.Map({
    container: "map",
    style,
    maxBounds: [
      [style.sources.vecinal.bounds[0], style.sources.vecinal.bounds[1]],
      [style.sources.vecinal.bounds[2], style.sources.vecinal.bounds[3]],
    ],
    maxZoom: style.sources.vecinal.maxzoom,
    locale: {
      "NavigationControl.ZoomIn": "Acercar",
      "NavigationControl.ZoomOut": "Alejar",
      "NavigationControl.ResetBearing": "Orientar hacia el norte",
    },
    attributionControl: false,
  });
  window.vecinalMap = map;
  map.addControl(new maplibregl.AttributionControl({ compact: false }));
  map.addControl(new maplibregl.NavigationControl(), "top-right");
  const recenter = document.getElementById("recenter");
  map.on("load", () => {
    recenter.disabled = false;
    recenter.addEventListener("click", () =>
      map.flyTo({
        center: style.center,
        zoom: Math.max(style.zoom, map.getMinZoom(), 14),
        bearing: 0,
        pitch: 0,
      }),
    );
  });
  let resourceFailed = false;
  map.on("error", (event) => {
    resourceFailed = true;
    statusElement.textContent =
      "No se pudo cargar una parte del mapa. Comprueba que los recursos y el servidor de teselas estén disponibles.";
    statusElement.dataset.error = "true";
    console.error(event.error);
  });
  map.on("idle", () => {
    if (!resourceFailed) statusElement.textContent = "Mapa listo para explorar";
  });
}

startMap().catch((error) => {
  statusElement.textContent =
    "No se pudo abrir el mapa. Comprueba que se hayan generado sus archivos.";
  statusElement.dataset.error = "true";
  console.error(error);
});
