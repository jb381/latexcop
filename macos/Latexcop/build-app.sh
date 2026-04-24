#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/.build/release/Latexcop.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
TRACKER_DIR="$RESOURCES_DIR/latexcop"
INSTALL_DIR="$HOME/Applications"
SYSTEM_INSTALL_DIR="/Applications"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$SCRIPT_DIR"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$TRACKER_DIR"
cp "$SCRIPT_DIR/.build/release/Latexcop" "$MACOS_DIR/Latexcop"
cp "$REPO_ROOT/progress_tracker.py" "$TRACKER_DIR/progress_tracker.py"
cp "$REPO_ROOT/pyproject.toml" "$TRACKER_DIR/pyproject.toml"
cp "$REPO_ROOT/uv.lock" "$TRACKER_DIR/uv.lock"
swift "$SCRIPT_DIR/scripts/make-icon.swift" "$RESOURCES_DIR/LatexcopIcon.icns"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Latexcop</string>
    <key>CFBundleIdentifier</key>
    <string>dev.latexcop.menubar</string>
    <key>CFBundleName</key>
    <string>Latexcop</string>
    <key>CFBundleIconFile</key>
    <string>LatexcopIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

if [[ "${1:-}" == "--install" ]]; then
    mkdir -p "$INSTALL_DIR"
    rm -rf "$INSTALL_DIR/Latexcop.app"
    cp -R "$APP_DIR" "$INSTALL_DIR/Latexcop.app"
    echo "$INSTALL_DIR/Latexcop.app"
    exit 0
fi

if [[ "${1:-}" == "--install-system" ]]; then
    rm -rf "$SYSTEM_INSTALL_DIR/Latexcop.app"
    cp -R "$APP_DIR" "$SYSTEM_INSTALL_DIR/Latexcop.app"
    echo "$SYSTEM_INSTALL_DIR/Latexcop.app"
    exit 0
fi

echo "$APP_DIR"
