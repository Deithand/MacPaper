#!/usr/bin/env bash
# Build MacPaper and wrap it into a minimal double-clickable .app bundle.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="MacPaper"
BUNDLE_ID="io.github.macpaper"
APP_DIR="${APP_NAME}.app"
MACOS_DIR="${APP_DIR}/Contents/MacOS"
RES_DIR="${APP_DIR}/Contents/Resources"

echo "▶︎ building release binary…"
swift build -c release

BIN=".build/release/${APP_NAME}"
if [[ ! -x "$BIN" ]]; then
  echo "build failed: $BIN not found" >&2
  exit 1
fi

echo "▶︎ assembling ${APP_DIR}…"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"
cp "$BIN" "$MACOS_DIR/${APP_NAME}"

cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>                 <string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key>          <string>${APP_NAME}</string>
  <key>CFBundleExecutable</key>           <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>           <string>${BUNDLE_ID}</string>
  <key>CFBundlePackageType</key>          <string>APPL</string>
  <key>CFBundleShortVersionString</key>   <string>0.1.0</string>
  <key>CFBundleVersion</key>              <string>1</string>
  <key>LSMinimumSystemVersion</key>       <string>13.0</string>
  <key>LSUIElement</key>                  <true/>
  <key>NSHighResolutionCapable</key>      <true/>
</dict>
</plist>
PLIST

# Ad-hoc sign so Gatekeeper accepts it locally.
codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true

echo "✓ built ${APP_DIR}"
echo "  run with:   open ${APP_DIR}"
