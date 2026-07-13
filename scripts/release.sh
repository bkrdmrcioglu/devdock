#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP_NAME="DevDock"
SCHEME="DevDock"
CONFIG="Release"

cd "$ROOT"

echo "==> Generating Xcode project"
command -v xcodegen >/dev/null || { echo "xcodegen required (brew install xcodegen)"; exit 1; }
xcodegen generate

echo "==> Building $CONFIG"
xcodebuild \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination 'platform=macOS' \
  -derivedDataPath "$ROOT/.derivedData" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES \
  build

PRODUCT="$ROOT/.derivedData/Build/Products/$CONFIG/$APP_NAME.app"
if [[ ! -d "$PRODUCT" ]]; then
  echo "Build product not found: $PRODUCT"
  exit 1
fi

mkdir -p "$DIST"
rm -rf "$DIST/$APP_NAME.app"
cp -R "$PRODUCT" "$DIST/$APP_NAME.app"

# Ad-hoc sign for local distribution (not notarized)
codesign --force --deep --sign - "$DIST/$APP_NAME.app" 2>/dev/null || true

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$DIST/$APP_NAME.app/Contents/Info.plist" 2>/dev/null || echo "unknown")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$DIST/$APP_NAME.app/Contents/Info.plist" 2>/dev/null || echo "?")"

ZIP="$DIST/${APP_NAME}-${VERSION}.zip"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$DIST/$APP_NAME.app" "$ZIP"

echo ""
echo "==> Release ready"
echo "    App: $DIST/$APP_NAME.app"
echo "    Zip: $ZIP"
echo "    Version: $VERSION ($BUILD)"
echo ""
echo "Open with: open \"$DIST/$APP_NAME.app\""
echo "Note: unsigned/ad-hoc — Gatekeeper may warn on other Macs until notarized."
