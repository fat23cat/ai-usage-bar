#!/usr/bin/env bash
# Zips the packaged app for a release and writes its SHA-256 next to it.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/AI Usage Bar.app"
test -d "$APP" || { echo "Run scripts/package_app.sh first." >&2; exit 2; }
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
ZIP="$ROOT/dist/AI-Usage-Bar-$VERSION.zip"

rm -f "$ZIP" "$ZIP.sha256"
# ditto keeps the bundle's signature and extended attributes intact.
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
(cd "$ROOT/dist" && shasum -a 256 "$(basename "$ZIP")" > "$(basename "$ZIP").sha256")
echo "$ZIP"
