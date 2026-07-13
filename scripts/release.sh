#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP_NAME="DevDock"
SCHEME="DevDock"
CONFIG="Release"
IDENTITY="${CODE_SIGN_IDENTITY:-Developer ID Application: Bekir Demircioglu (HLZQLSTBB8)}"
TEAM="${DEVELOPMENT_TEAM:-HLZQLSTBB8}"

cd "$ROOT"

echo "==> Generating Xcode project"
command -v xcodegen >/dev/null || { echo "xcodegen required (brew install xcodegen)"; exit 1; }
xcodegen generate

echo "==> Building $CONFIG ($IDENTITY)"
xcodebuild \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination 'platform=macOS' \
  -derivedDataPath "$ROOT/.derivedData" \
  CODE_SIGN_IDENTITY="$IDENTITY" \
  DEVELOPMENT_TEAM="$TEAM" \
  CODE_SIGNING_ALLOWED=YES \
  OTHER_CODE_SIGN_FLAGS="--timestamp" \
  build

PRODUCT="$ROOT/.derivedData/Build/Products/$CONFIG/$APP_NAME.app"
if [[ ! -d "$PRODUCT" ]]; then
  echo "Build product not found: $PRODUCT"
  exit 1
fi

mkdir -p "$DIST"
rm -rf "$DIST/$APP_NAME.app"
cp -R "$PRODUCT" "$DIST/$APP_NAME.app"

# Asset catalogs often thin the Dock icon; keep the full handcrafted icns.
if [[ -f "$ROOT/DevDock/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/DevDock/Resources/AppIcon.icns" "$DIST/$APP_NAME.app/Contents/Resources/AppIcon.icns"
fi
rm -f "$DIST/$APP_NAME.app/Contents/Resources/DevDockIcon-1024.png"

echo "==> Codesigning"
codesign --force --deep --options runtime --timestamp \
  --sign "$IDENTITY" \
  "$DIST/$APP_NAME.app"
codesign --verify --verbose=2 "$DIST/$APP_NAME.app"

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
echo "    SHA256: $(shasum -a 256 "$ZIP" | awk '{print $1}')"
echo ""
echo "Open with: open \"$DIST/$APP_NAME.app\""
echo "Notarize next (needs notarytool profile):"
echo "  xcrun notarytool submit \"$ZIP\" --keychain-profile \"NotaryProfile\" --wait"
echo "  xcrun stapler staple \"$DIST/$APP_NAME.app\""
