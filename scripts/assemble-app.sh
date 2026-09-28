#!/usr/bin/env bash
# Build and sign HideNotch.app at .build/HideNotch.app. Usage: assemble-app.sh <sign-identity>
set -euo pipefail
cd "$(dirname "$0")/.."

if [ $# -lt 1 ]; then
    echo "usage: $0 <sign-identity>" >&2
    exit 2
fi
IDENTITY="$1"

swift build -c release

APP=".build/HideNotch.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/HideNotch "$APP/Contents/MacOS/HideNotch"
cp Resources/Info.plist "$APP/Contents/Info.plist"

ICONSET=".build/AppIcon.iconset"
rm -rf "$ICONSET"
.build/release/IconGen "$ICONSET"
mkdir -p "$APP/Contents/Resources"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

if [ "$IDENTITY" = "-" ]; then
    codesign --force --sign - "$APP"
else
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
fi

codesign --verify --strict --verbose=2 "$APP"

echo "Assembled $APP"
