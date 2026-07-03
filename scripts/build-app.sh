#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/build/AppleStack.app"
DMG_STAGING_DIR="$ROOT_DIR/build/dmg"
DMG_PATH="$ROOT_DIR/build/AppleStack.dmg"
EXECUTABLE="$ROOT_DIR/.build/release/AppleStack"

cd "$ROOT_DIR"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/AppleStack"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP_DIR/Contents/PkgInfo"

echo "Built $APP_DIR"

rm -rf "$DMG_STAGING_DIR" "$DMG_PATH"
mkdir -p "$DMG_STAGING_DIR"
cp -R "$APP_DIR" "$DMG_STAGING_DIR/AppleStack.app"
ln -s /Applications "$DMG_STAGING_DIR/Applications"
cat > "$DMG_STAGING_DIR/First Open.txt" <<'EOF'
AppleStack first open

1. Drag AppleStack.app to Applications.
2. Open AppleStack from Applications. Because this build is unsigned, macOS may require Control-click > Open the first time.
3. In AppleStack, confirm the container CLI path in Settings > CLI before creating resources.
EOF
hdiutil create \
    -volname "AppleStack" \
    -srcfolder "$DMG_STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo "Built $DMG_PATH"
