#!/usr/bin/env bash
# Copia MapLibre GL JS (JS y CSS) a web/vendor/maplibre para que el sitio lo sirva desde su propio
# origen y la CSP no tenga que permitir otro dominio. Correr antes de `flutter run -d chrome` o de
# `flutter build web`. La versión sigue la que indica el README de maplibre_gl para web.
set -euo pipefail

VERSION="${MAPLIBRE_GL_VERSION:-5.6.0}"
cd "$(dirname "$0")/.."

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# npm verifica la integridad del paquete contra el registro.
npm pack --silent --pack-destination "$tmp" "maplibre-gl@${VERSION}" >/dev/null
tar -xzf "$tmp"/maplibre-gl-*.tgz -C "$tmp"

mkdir -p web/vendor/maplibre
cp "$tmp/package/dist/maplibre-gl.js" "$tmp/package/dist/maplibre-gl.css" web/vendor/maplibre/
cp "$tmp/package/LICENSE.txt" web/vendor/maplibre/LICENSE.txt 2>/dev/null || true
echo "maplibre-gl ${VERSION} copiado en web/vendor/maplibre"
