#!/usr/bin/env bash
# Escribe build/web/_headers para Cloudflare Pages: CSP con los orígenes de la API y de la CDN del
# entorno, index.html sin caché y los encabezados de seguridad de siempre.
#
# Uso: tool/write_headers.sh https://api.staging.<dominio> https://cdn.staging.<dominio> [build/web]
set -euo pipefail

API_ORIGIN="${1:?Falta el origen de la API (https://...)}"
CDN_ORIGIN="${2:?Falta el origen de la CDN (https://...)}"
OUT_DIR="${3:-build/web}"

for origin in "$API_ORIGIN" "$CDN_ORIGIN"; do
  case "$origin" in
    https://*) ;;
    *) echo "Los orígenes deben ser https:// ($origin)" >&2; exit 1 ;;
  esac
done
[ -d "$OUT_DIR" ] || { echo "No existe $OUT_DIR: compila primero con flutter build web" >&2; exit 1; }

# Firebase Authentication y su reCAPTCHA invisible, solo si PHONE_AUTH=firebase.
FIREBASE="https://identitytoolkit.googleapis.com https://securetoken.googleapis.com https://www.googleapis.com"
RECAPTCHA="https://www.google.com https://www.gstatic.com https://www.recaptcha.net"

# Flutter web necesita 'wasm-unsafe-eval' (CanvasKit) y estilos en línea; MapLibre, workers blob:.
CSP="default-src 'self'"
CSP+="; script-src 'self' 'wasm-unsafe-eval' ${RECAPTCHA}"
CSP+="; style-src 'self' 'unsafe-inline'"
CSP+="; img-src 'self' data: blob: ${CDN_ORIGIN}"
CSP+="; font-src 'self' https://fonts.gstatic.com"
CSP+="; connect-src 'self' ${API_ORIGIN} ${CDN_ORIGIN} ${FIREBASE} https://fonts.gstatic.com"
CSP+="; worker-src 'self' blob:"
CSP+="; child-src blob:"
CSP+="; frame-src ${RECAPTCHA} https://*.firebaseapp.com"
CSP+="; object-src 'none'; base-uri 'self'; form-action 'none'; frame-ancestors 'none'"

cat > "$OUT_DIR/_headers" <<EOF
/*
  Content-Security-Policy: ${CSP}
  X-Content-Type-Options: nosniff
  Referrer-Policy: no-referrer
  X-Frame-Options: DENY
  Permissions-Policy: camera=(), microphone=(), geolocation=(), payment=()

/
  Cache-Control: no-store

/index.html
  Cache-Control: no-store
EOF

echo "Encabezados escritos en $OUT_DIR/_headers"
