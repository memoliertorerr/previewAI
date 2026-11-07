#!/usr/bin/env bash
# Builds a Developer ID-signed, notarized, stapled PreviewAI.zip in dist/.
# Usage: scripts/release.sh "Developer ID Application: Your Name (TEAMID)" <notarytool-keychain-profile>
# One-time setup: see docs/DISTRIBUTION.md.
set -euo pipefail

identity="${1:?Developer ID Application identity required}"
profile="${2:?notarytool keychain profile required}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
app="build/PreviewAI.app"
zip="dist/PreviewAI-$version.zip"

make app
codesign --force --options runtime --timestamp \
  --entitlements Resources/PreviewAI-DeveloperID.entitlements \
  --sign "$identity" "$app"
codesign --verify --deep --strict --verbose=2 "$app"

# No extended attributes in the zip: third-party unzippers turn them into "._*" files inside
# the bundle, which breaks the signature (macOS then calls the app "damaged").
zipapp() { ditto -c -k --norsrc --noextattr --noacl --keepParent "$app" "$zip"; }

mkdir -p dist
rm -f "$zip"
zipapp
xcrun notarytool submit "$zip" --keychain-profile "$profile" --wait
xcrun stapler staple "$app"
rm -f "$zip"
zipapp
spctl --assess --type execute --verbose "$app"
scripts/check-zip.sh "$zip" --notarized
echo "release: $zip"
