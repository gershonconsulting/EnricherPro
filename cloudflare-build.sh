#!/usr/bin/env bash
#
# Cloudflare Pages build for EnricherPro.
#
# Pages settings that go with this script:
#   Build command:      bash cloudflare-build.sh
#   Output directory:   build/web
#   Environment vars:   MILLIONVERIFIER_API_KEY (secret, Production + Preview)
#
# The Pages build image has no Flutter SDK, so we fetch a pinned one.
#
# The version is pinned deliberately: an unpinned `-b stable` means a Flutter
# release can break a deploy on a day nobody touched this repo. It must stay
# >= the Dart SDK constraint in pubspec.yaml (currently ^3.9.2) -- pinning
# 3.24.5 here failed the first build because it ships Dart 3.5.4.

set -euo pipefail

FLUTTER_VERSION="3.47.5"
FLUTTER_DIR="$HOME/flutter"

echo "==> Fetching Flutter ${FLUTTER_VERSION}"
if [ ! -d "$FLUTTER_DIR" ]; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"

# Pages runs the build as a non-root user in a fresh container; Flutter warns
# about the repo not being owned by the current user unless we say it is fine.
git config --global --add safe.directory "$FLUTTER_DIR" || true

flutter --version
flutter config --enable-web --no-analytics
flutter pub get

echo "==> Building web (release)"
flutter build web --release

# The worker must sit at the ROOT of the published output, beside index.html.
# Pages runs it in advanced mode and hands it the static files via env.ASSETS.
echo "==> Installing _worker.js into build/web"
cp _worker.js build/web/_worker.js

echo "==> Done. Published files:"
ls -la build/web | head -20
