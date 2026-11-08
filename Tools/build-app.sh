#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Novaloria"
PRODUCT_NAME="Novaloria"
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-debug}"
APP_VERSION="$(sed -n 's/^[[:space:]]*static let version = "\([^"]*\)".*/\1/p' \
    "$PROJECT_DIR/Sources/Novaloria/AppVersion.swift")"

if [[ -z "$APP_VERSION" ]]; then
    echo "Could not read app version from AppVersion.swift" >&2
    exit 1
fi

echo "Building $APP_NAME..."
swift build --package-path "$PROJECT_DIR" --configuration "$BUILD_CONFIGURATION" --product "$PRODUCT_NAME"

BIN_DIR="$(swift build --package-path "$PROJECT_DIR" --configuration "$BUILD_CONFIGURATION" --show-bin-path)"
SOURCE_BIN="$BIN_DIR/$PRODUCT_NAME"

APP_BUNDLE="$BIN_DIR/$APP_NAME.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

ICON_SOURCE="$PROJECT_DIR/Sources/Novaloria/Resources/novaloria-app-icon.svg"
ICONSET_DIR="$(mktemp -d)"
trap 'rm -rf "$ICONSET_DIR"' EXIT
ICONSET="$ICONSET_DIR/Novaloria.iconset"
mkdir -p "$ICONSET"

sips -s format png "$ICON_SOURCE" --out "$ICONSET_DIR/novaloria-app-icon.png" >/dev/null
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ICONSET_DIR/novaloria-app-icon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double_size=$((size * 2))
    sips -z "$double_size" "$double_size" "$ICONSET_DIR/novaloria-app-icon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP_BUNDLE/Contents/Resources/Novaloria.icns"

cp "$SOURCE_BIN" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
ditto "$BIN_DIR/Novaloria_Novaloria.bundle" \
    "$APP_BUNDLE/Contents/Resources/Novaloria_Novaloria.bundle"

cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.novaloria.client</string>
    <key>CFBundleIconFile</key>
    <string>Novaloria.icns</string>
    <key>CFBundleName</key>
    <string>Novaloria</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
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
