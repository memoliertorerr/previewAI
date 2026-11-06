#!/usr/bin/env bash
# Assembles a .app bundle from a built PreviewAI binary and ad-hoc signs it.
# Usage: scripts/bundle.sh <path-to-binary> <output .app path>
set -euo pipefail

binary="$1"
app="$2"
root="$(cd "$(dirname "$0")/.." && pwd)"

case "$app" in
  /*) ;; *) app="$root/$app" ;;
esac
# Only ever write inside the repo.
case "$app" in
  "$root"/*) ;; *) echo "bundle.sh: refusing to write outside the repo: $app" >&2; exit 1 ;;
esac

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary" "$app/Contents/MacOS/PreviewAI"
cp "$root/Resources/Info.plist" "$app/Contents/Info.plist"
printf 'APPL????' > "$app/Contents/PkgInfo"
codesign --force --sign - --timestamp=none "$app" >/dev/null
echo "bundle: $app"
