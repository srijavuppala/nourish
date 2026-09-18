#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CI=true
export TAR_OPTIONS=--no-same-owner
export FLUTTER_SUPPRESS_ANALYTICS=true
flutter_bin="${FLUTTER_BIN:-/tmp/nourish-flutter/bin/flutter}"
"$flutter_bin" build web --release --no-web-resources-cdn --pwa-strategy=none
mkdir -p dist/server dist/client dist/.openai
cp -R build/web/. dist/client/
cp server/index.js dist/server/index.js
cp .openai/hosting.json dist/.openai/hosting.json
