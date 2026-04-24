#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="${1:-dev}"
APP_DIR="$SCRIPT_DIR/.build/release/Latexcop.app"
DIST_DIR="$SCRIPT_DIR/.build/dist"
DMG_ROOT="$DIST_DIR/dmg-root"
DMG_PATH="$DIST_DIR/Latexcop-$VERSION.dmg"

cd "$SCRIPT_DIR"
./build-app.sh >/dev/null

rm -rf "$DIST_DIR"
mkdir -p "$DMG_ROOT"
cp -R "$APP_DIR" "$DMG_ROOT/Latexcop.app"
ln -s /Applications "$DMG_ROOT/Applications"

hdiutil create \
    -volname "Latexcop" \
    -srcfolder "$DMG_ROOT" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

echo "$DMG_PATH"
