#!/usr/bin/env bash
# Build HideNotch.app (ad-hoc signed) and install it to ~/Applications.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP=".build/HideNotch.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/HideNotch "$APP/Contents/MacOS/HideNotch"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

DEST="$HOME/Applications"
mkdir -p "$DEST"
rm -rf "$DEST/HideNotch.app"
cp -R "$APP" "$DEST/"
echo "Installed $DEST/HideNotch.app"
