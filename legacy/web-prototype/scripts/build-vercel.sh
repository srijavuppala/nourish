#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true
export TAR_OPTIONS=--no-same-owner
# Connector deployments transport the three images as text. Git deployments use
# the original JPG files and skip this step.
if [ -d .deploy-assets ]; then
  mkdir -p assets/images
  for encoded in .deploy-assets/*.base64; do
    filename="$(basename "$encoded" .base64)"
    base64 --decode "$encoded" > "assets/images/$filename"
  done
fi
flutter_bin="${FLUTTER_BIN:-/tmp/nourish-flutter/bin/flutter}"
if [ ! -x "$flutter_bin" ]; then
  git clone --depth 1 --branch 3.47.4 https://github.com/flutter/flutter.git /tmp/nourish-flutter
fi
"$flutter_bin" config --no-analytics
"$flutter_bin" pub get
"$flutter_bin" build web --no-pub --release --no-web-resources-cdn --pwa-strategy=none --dart-define=DEMO_MODE=true
