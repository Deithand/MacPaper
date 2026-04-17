#!/usr/bin/env bash
# Build MacPaper.app, then wrap it into a distributable flat .pkg installer
# that drops MacPaper.app into /Applications.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="MacPaper"
BUNDLE_ID="io.github.macpaper"
APP_DIR="${APP_NAME}.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${APP_DIR}/Contents/Info.plist" 2>/dev/null || echo 0.1.0)"
PKG="${APP_NAME}-${VERSION}.pkg"
STAGE=".build/pkg-root"

# 1. Ensure the .app is built.
if [[ ! -d "$APP_DIR" ]]; then
  echo "▶︎ app bundle missing, building…"
  ./scripts/make-app.sh
fi

# 2. Stage payload with the exact install layout.
echo "▶︎ staging /Applications payload…"
rm -rf "$STAGE"
mkdir -p "$STAGE/Applications"
cp -R "$APP_DIR" "$STAGE/Applications/"

# 3. Build the component .pkg.
rm -f "$PKG"
echo "▶︎ building ${PKG}…"
pkgbuild \
  --root "$STAGE" \
  --identifier "$BUNDLE_ID" \
  --version "$VERSION" \
  --install-location "/" \
  "$PKG" >/dev/null

rm -rf "$STAGE"

echo "✓ built $PKG"
echo "  install with:   open \"$PKG\""
