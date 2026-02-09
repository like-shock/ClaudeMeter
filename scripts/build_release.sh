#!/bin/bash
set -e

VERSION="1.0.0"
APP_NAME="claude_meter"

echo "=== Flutter Release Build ==="
flutter clean
flutter pub get
flutter build macos --release

APP="build/macos/Build/Products/Release/$APP_NAME.app"

if [ ! -d "$APP" ]; then
  echo "ERROR: Build failed — .app not found"
  exit 1
fi

echo "=== Creating DMG ==="
DMG_NAME="ClaudeMeter-$VERSION.dmg"
rm -f "$DMG_NAME"

hdiutil create -volname "Claude Meter" \
  -srcfolder "$APP" \
  -ov -format UDZO \
  "$DMG_NAME"

echo ""
echo "=== Build Complete ==="
echo "DMG: $DMG_NAME"
echo "Size: $(du -h "$DMG_NAME" | cut -f1)"
echo ""
echo "배포 후 사용자 안내:"
echo "  xattr -cr /Applications/$APP_NAME.app"
