#!/usr/bin/env bash
# Verificación completa de la app (macOS/Linux y CI): plataformas si faltan, dependencias,
# localización, análisis, pruebas y formato. Uso: desde app/, `tool/verify.sh`.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -d android ]; then
  flutter create --platforms=android,ios --org pe.shabatshalom --project-name vecinal .
fi
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed lib test
echo "✓ App verificada"
