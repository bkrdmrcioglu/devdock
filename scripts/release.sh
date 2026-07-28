#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP_NAME="DevDock"
SCHEME="DevDock"
CONFIG="Release"
IDENTITY="${CODE_SIGN_IDENTITY:-12392A31803093ED388B618318523BA4000AB9E0}" # Developer ID Application (SHA-1) — name is ambiguous, two identical certs in keychain
TEAM="${DEVELOPMENT_TEAM:-HLZQLSTBB8}"
NOTARY_PROFILE="${NOTARY_PROFILE:-NotaryProfile}"

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
SHA="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
echo "$SHA" > "$ZIP.sha256"

echo ""
echo "==> Package ready"
echo "    App: $DIST/$APP_NAME.app"
echo "    Zip: $ZIP"
echo "    Version: $VERSION ($BUILD)"
echo "    SHA256: $SHA"

if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  echo "==> Notarizing with profile $NOTARY_PROFILE"
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DIST/$APP_NAME.app"
  rm -f "$ZIP"
  ditto -c -k --sequesterRsrc --keepParent "$DIST/$APP_NAME.app" "$ZIP"
  SHA="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
  echo "$SHA" > "$ZIP.sha256"
  echo "==> Stapled. SHA256: $SHA"
else
  echo "==> Skipping notarization (no keychain profile \"$NOTARY_PROFILE\")"
fi

echo ""
echo "GitHub:"
echo "  gh release create v${VERSION} \"$ZIP\" --repo bkrdmrcioglu/devdock --title \"DevDock ${VERSION}\""
echo "Homebrew: set version/sha256 $SHA in Casks/devdock.rb (this repo)"