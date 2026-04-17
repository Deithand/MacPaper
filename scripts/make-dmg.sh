#!/usr/bin/env bash
# Build MacPaper.app, then wrap it into a distributable .dmg
# with a drag-to-Applications layout.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="MacPaper"
APP_DIR="${APP_NAME}.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${APP_DIR}/Contents/Info.plist" 2>/dev/null || echo 0.1.0)"
DMG="${APP_NAME}-${VERSION}.dmg"
STAGE=".build/dmg-stage"

# 1. Ensure the .app is built.
if [[ ! -d "$APP_DIR" ]]; then
  echo "▶︎ app bundle missing, building…"
  ./scripts/make-app.sh
fi

# 2. Prepare a staging folder for the DMG contents.
echo "▶︎ staging DMG tree…"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP_DIR" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

# 3. Build the DMG (UDZO = compressed, read-only).
rm -f "$DMG"
echo "▶︎ packaging ${DMG}…"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  -fs HFS+ \
  "$DMG" >/dev/null

rm -rf "$STAGE"

echo "✓ built $DMG"
echo "  open with:  open \"$DMG\""
