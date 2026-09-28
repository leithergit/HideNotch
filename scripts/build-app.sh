#!/usr/bin/env bash
# Build HideNotch.app (ad-hoc signed) and install it to ~/Applications.
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/assemble-app.sh -

APP=".build/HideNotch.app"
DEST="$HOME/Applications"
mkdir -p "$DEST"
rm -rf "$DEST/HideNotch.app"
cp -R "$APP" "$DEST/"
echo "Installed $DEST/HideNotch.app"
