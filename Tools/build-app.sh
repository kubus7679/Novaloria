#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="FreeCol"
PRODUCT_NAME="FreeColApp"

echo "Building $APP_NAME..."
swift build --package-path "$PROJECT_DIR" --product "$PRODUCT_NAME"

BIN_DIR="$(swift build --package-path "$PROJECT_DIR" --show-bin-path)"
SOURCE_BIN="$BIN_DIR/$PRODUCT_NAME"

APP_BUNDLE="$BIN_DIR/$APP_NAME.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$SOURCE_BIN" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
ditto "$BIN_DIR/FreeColClient_FreeColApp.bundle" \
    "$APP_BUNDLE/Contents/Resources/FreeColClient_FreeColApp.bundle"

cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>net.sf.freecol.FreeColClient</string>
    <key>CFBundleName</key>
    <string>FreeCol</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo ""
echo "✅ $APP_BUNDLE"
echo "Run: open \"$APP_BUNDLE\""
