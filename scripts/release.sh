#!/usr/bin/env bash
# Builds a Developer ID-signed, notarized, stapled PreviewAI.zip in dist/.
# Usage: scripts/release.sh "Developer ID Application: Your Name (TEAMID)" <notarytool-keychain-profile>
# One-time setup: see docs/DISTRIBUTION.md. Untested until run with a real certificate.
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

mkdir -p dist
rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"
xcrun notarytool submit "$zip" --keychain-profile "$profile" --wait
xcrun stapler staple "$app"
rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"
spctl --assess --type execute --verbose "$app"
echo "release: $zip"
