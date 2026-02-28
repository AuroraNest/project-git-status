#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

usage() {
  cat >&2 <<'EOF'
Usage: scripts/package_macos.sh [Debug|Release] [--install]

Options:
  --install    After packaging, replace /Applications/GitRepoManager.app
EOF
}

CONFIG="Release"
INSTALL_TO_APPLICATIONS=0

for arg in "$@"; do
  case "$arg" in
    Debug|Release)
      CONFIG="$arg"
      ;;
    --install)
      INSTALL_TO_APPLICATIONS=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

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
APPLICATIONS_APP="/Applications/$APP_NAME"

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

if [[ "$INSTALL_TO_APPLICATIONS" -eq 1 ]]; then
  rm -rf "$APPLICATIONS_APP"
  ditto "$APP_SRC" "$APPLICATIONS_APP"
fi

echo "OK:"
echo "  $OUT_DIR/$APP_NAME"
echo "  $OUT_DIR/$ZIP_NAME"
echo "  $OUT_DIR/$DMG_NAME"
if [[ "$INSTALL_TO_APPLICATIONS" -eq 1 ]]; then
  echo "  installed: $APPLICATIONS_APP"
fi
