#!/usr/bin/env bash
# Checks that a release zip unpacks to a valid app with *any* unzip tool, not just Apple's.
# Usage: scripts/check-zip.sh <zip> [--notarized]
# Third-party extractors (e.g. Parallels Toolbox "Unarchive") write AppleDouble "._*" entries as
# real files inside the bundle, which breaks the signature ("PreviewAI is damaged"). So: no "._*"
# entries allowed, and the app must verify after a plain /usr/bin/unzip.
set -euo pipefail

zip="${1:?zip path required}"
notarized="${2:-}"
root="$(cd "$(dirname "$0")/.." && pwd)"
scratch="$root/.build/zip-check"

if /usr/bin/unzip -Z1 "$zip" | grep -E '(^|/)\._|^__MACOSX/' >/dev/null; then
  echo "check-zip: $zip contains AppleDouble (._*) or __MACOSX entries" >&2
  exit 1
fi

rm -rf "$scratch"
mkdir -p "$scratch"
/usr/bin/unzip -q "$zip" -d "$scratch"
app="$scratch/PreviewAI.app"
codesign --verify --deep --strict "$app"
if [[ "$notarized" == "--notarized" ]]; then
  xcrun stapler validate -q "$app"
  spctl --assess --type execute "$app"
  syspolicy_check distribution "$app"
fi
rm -rf "$scratch"
echo "check-zip: ok ($zip)"
