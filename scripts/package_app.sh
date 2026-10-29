#!/usr/bin/env bash
# Builds and signs "dist/AI Usage Bar.app".
#
#   VERSION=1.2.3          bundle version (default: latest v* tag, else 0.0.0)
#   UNIVERSAL=1            arm64 + x86_64 (needs Xcode, as on GitHub runners)
#   AIUSAGEBAR_SIGNING_IDENTITY="Developer ID Application: …"
#                          code-signing identity (default: ad-hoc "-")
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/AI Usage Bar.app"
IDENTITY="${AIUSAGEBAR_SIGNING_IDENTITY:--}"

cd "$ROOT"
if [ "${UNIVERSAL:-0}" = 1 ]; then
    swift build -c release --product AIUsageBar --arch arm64 --arch x86_64
    BINARY="$ROOT/.build/apple/Products/Release/AIUsageBar"
else
    swift build -c release --product AIUsageBar
    BINARY="$(swift build -c release --show-bin-path)/AIUsageBar"
fi

if [ -z "${VERSION:-}" ]; then
    TAG="$(git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null || true)"
    VERSION="${TAG#v}"
    VERSION="${VERSION:-0.0.0}"
fi
echo "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' ||
    { echo "VERSION must look like 1.2.3, got '$VERSION'" >&2; exit 2; }

# Build identity "YYYY-MM-DD <commit>[+]"; Settings shows it next to the version.
COMMIT="$(git rev-parse --short=7 HEAD 2>/dev/null || echo unknown)"
if [ -n "$(git status --porcelain --untracked-files=no 2>/dev/null)" ]; then COMMIT="$COMMIT+"; fi
BUILD_ID="$(date +%Y-%m-%d) $COMMIT"
BUNDLE_VERSION="$(git rev-list --count HEAD 2>/dev/null || echo 1)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/AIUsageBar"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"
PLIST="$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUNDLE_VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :AIUsageBarBuildId string $BUILD_ID" "$PLIST"
chmod +x "$APP/Contents/MacOS/AIUsageBar"

# Sign the whole bundle after writing its metadata. A certificate identity keeps
# Keychain "Always Allow" valid across updates; an ad-hoc signature is tied to
# this exact build, so macOS asks again after each rebuild.
SIGN_ARGS=(--force --sign "$IDENTITY" --identifier org.aiusagebar.app)
if [ "$IDENTITY" != "-" ]; then SIGN_ARGS+=(--options runtime --timestamp); fi
codesign "${SIGN_ARGS[@]}" "$APP"
codesign --verify --deep --strict "$APP"
/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$PLIST" | grep -Fx true >/dev/null
echo "Packaged AI Usage Bar $VERSION ($BUILD_ID) at $APP"
