#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist}"
APP_NAME="${APP_NAME:-Buoy}"
APP_DIR="$OUTPUT_DIR/$APP_NAME.app"
SWIFTC="${SWIFTC:-xcrun swiftc}"

"$ROOT_DIR/scripts/build-cli.sh"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources/bin"

cat > "$APP_DIR/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>Buoy</string>
  <key>CFBundleIdentifier</key>
  <string>com.scwlkr.buoy</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Buoy</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

echo "Building Buoy.app..."
"${SWIFTC}" \
  -framework AppKit \
  "$ROOT_DIR"/Sources/BuoyCore/*.swift \
  "$ROOT_DIR"/Sources/BuoyApp/main.swift \
  -o "$APP_DIR/Contents/MacOS/Buoy"

cp "$OUTPUT_DIR/buoy" "$APP_DIR/Contents/Resources/bin/buoy"
ln -sf buoy "$APP_DIR/Contents/Resources/bin/healthyservermac"
chmod +x "$APP_DIR/Contents/MacOS/Buoy" "$APP_DIR/Contents/Resources/bin/buoy"

echo "App built at $APP_DIR"
