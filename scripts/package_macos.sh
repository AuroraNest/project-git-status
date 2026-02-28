#!/usr/bin/env bash
set -euo pipefail

CONFIG="${1:-Release}"
if [[ "$CONFIG" != "Debug" && "$CONFIG" != "Release" ]]; then
  echo "Usage: $0 [Debug|Release]" >&2
  exit 2
fi

# Use full Xcode by default (xcodebuild fails if xcode-select points to CommandLineTools).
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

PROJECT="GitRepoManager.xcodeproj"
SCHEME="GitRepoManager"

DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/grm-deriveddata}"

if [[ "$CONFIG" == "Release" ]]; then
  OUT_DIR="${OUT_DIR:-release}"
  ZIP_NAME="${ZIP_NAME:-GitRepoManager-macOS.zip}"
  DMG_NAME="${DMG_NAME:-GitRepoManager-macOS.dmg}"
else
  OUT_DIR="${OUT_DIR:-release-debug}"
  ZIP_NAME="${ZIP_NAME:-GitRepoManager-macOS-Debug.zip}"
  DMG_NAME="${DMG_NAME:-GitRepoManager-macOS-Debug.dmg}"
fi

APP_NAME="GitRepoManager.app"
DMG_VOL_NAME="${DMG_VOL_NAME:-GitRepoManager}"
DMG_STAGING_DIR="${DMG_STAGING_DIR:-/tmp/grm-dmg-staging}"

rm -rf "$OUT_DIR/$APP_NAME" "$OUT_DIR/$ZIP_NAME" "$OUT_DIR/$DMG_NAME" "$DMG_STAGING_DIR"
mkdir -p "$OUT_DIR"

DEVELOPER_DIR="$DEVELOPER_DIR" xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -destination "platform=macOS" \
  clean build

APP_SRC="$DERIVED_DATA_PATH/Build/Products/$CONFIG/$APP_NAME"
if [[ ! -d "$APP_SRC" ]]; then
  echo "Build succeeded but app not found: $APP_SRC" >&2
  exit 1
fi

# Use ditto to preserve macOS bundle metadata/resource forks.
ditto "$APP_SRC" "$OUT_DIR/$APP_NAME"
ditto -c -k --sequesterRsrc --keepParent "$OUT_DIR/$APP_NAME" "$OUT_DIR/$ZIP_NAME"

mkdir -p "$DMG_STAGING_DIR"
ditto "$OUT_DIR/$APP_NAME" "$DMG_STAGING_DIR/$APP_NAME"
ln -s /Applications "$DMG_STAGING_DIR/Applications"
hdiutil create \
  -volname "$DMG_VOL_NAME" \
  -srcfolder "$DMG_STAGING_DIR" \
  -ov \
  -format UDZO \
  "$OUT_DIR/$DMG_NAME" >/dev/null
rm -rf "$DMG_STAGING_DIR"

echo "OK:"
echo "  $OUT_DIR/$APP_NAME"
echo "  $OUT_DIR/$ZIP_NAME"
echo "  $OUT_DIR/$DMG_NAME"
