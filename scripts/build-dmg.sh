#!/usr/bin/env bash
# Build, sign, notarize, and staple a distributable HideNotch DMG in dist/.
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="${HIDENOTCH_SIGN_IDENTITY:-Developer ID Application: XIONGGAO LI (Z8NL57N2AP)}"
PROFILE="${HIDENOTCH_NOTARY_PROFILE:-HideNotch}"

scripts/assemble-app.sh "$IDENTITY"

APP=".build/HideNotch.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)

STAGING=".build/dmg-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

mkdir -p dist
DMG="dist/HideNotch-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "HideNotch" -srcfolder "$STAGING" -ov -format UDZO "$DMG"

codesign --force --timestamp --sign "$IDENTITY" "$DMG"

SUBMIT_JSON=$(xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait --output-format json)
echo "$SUBMIT_JSON"

if command -v /usr/bin/python3 >/dev/null 2>&1; then
    NOTARY_ID=$(echo "$SUBMIT_JSON" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')
    NOTARY_STATUS=$(echo "$SUBMIT_JSON" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["status"])')
else
    NOTARY_ID=$(echo "$SUBMIT_JSON" | plutil -extract id raw -)
    NOTARY_STATUS=$(echo "$SUBMIT_JSON" | plutil -extract status raw -)
fi

echo "Notarization id: $NOTARY_ID"
echo "Notarization status: $NOTARY_STATUS"

if [ "$NOTARY_STATUS" != "Accepted" ]; then
    echo "Notarization failed; fetching log:" >&2
    xcrun notarytool log "$NOTARY_ID" --keychain-profile "$PROFILE"
    exit 1
fi

xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"

echo "DMG: $DMG"
shasum -a 256 "$DMG"
