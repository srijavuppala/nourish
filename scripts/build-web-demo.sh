#!/usr/bin/env bash
# Builds the demo-mode web app — the build to deploy for a shareable link.
#
# Demo mode needs no Firebase project and no API keys: storage is the
# browser's own and meal parsing runs on-device. See README.
set -euo pipefail
cd "$(dirname "$0")/.."

export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true

# Vercel and most CI images have no Flutter, so fetch the pinned SDK once.
flutter_bin="${FLUTTER_BIN:-/tmp/nourish-flutter/bin/flutter}"
if [ ! -x "$flutter_bin" ]; then
  if command -v flutter >/dev/null 2>&1; then
    flutter_bin="$(command -v flutter)"
  else
    git clone --depth 1 --branch 3.47.4 \
      https://github.com/flutter/flutter.git /tmp/nourish-flutter
  fi
fi

"$flutter_bin" --version
"$flutter_bin" pub get

# --no-web-resources-cdn keeps CanvasKit local, so the app also works offline
# and behind a restrictive network.
"$flutter_bin" build web \
  --release \
  --no-web-resources-cdn \
  --dart-define=DEMO_MODE=true
