#!/usr/bin/env bash
#
# Builds a Release Pilcrow.app and a shareable Pilcrow.zip into macos/build/.
# Ad-hoc signs by default (works for GitHub sharing — recipients bypass
# Gatekeeper once, see README). Set DEVELOPER_ID_IDENTITY (+ DEVELOPMENT_TEAM)
# for a distributable signed build, and NOTARY_PROFILE to notarize and staple.
#
#   ./scripts/build-release.sh
#   DEVELOPER_ID_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
#     DEVELOPMENT_TEAM=TEAMID NOTARY_PROFILE=pilcrow-notary ./scripts/build-release.sh
#
set -euo pipefail
cd "$(dirname "$0")/.."

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
CONFIG=Release
BUILD_DIR="$PWD/build"
DD="$BUILD_DIR/DerivedData"
APP_NAME="Pilcrow"
mkdir -p "$BUILD_DIR"

echo "==> Preparing bundled tools..."
bash scripts/prepare-assets.sh

echo "==> Generating project..."
xcodegen generate >/dev/null

if [ -n "${DEVELOPER_ID_IDENTITY:-}" ]; then
  echo "==> Signing with Developer ID: $DEVELOPER_ID_IDENTITY"
  SIGN_ARGS=(CODE_SIGN_STYLE=Manual \
             "CODE_SIGN_IDENTITY=$DEVELOPER_ID_IDENTITY" \
             "OTHER_CODE_SIGN_FLAGS=--timestamp --options=runtime")
  if [ -n "${DEVELOPMENT_TEAM:-}" ]; then
    SIGN_ARGS+=("DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM")
  fi
else
  echo "==> No DEVELOPER_ID_IDENTITY set - ad-hoc signing (GitHub-shareable; recipients bypass Gatekeeper once)."
  SIGN_ARGS=(CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES)
fi

echo "==> Building $CONFIG..."
xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$APP_NAME" -configuration "$CONFIG" \
  -derivedDataPath "$DD" -destination 'generic/platform=macOS' \
  "${SIGN_ARGS[@]}" build

APP="$DD/Build/Products/$CONFIG/$APP_NAME.app"
rm -rf "$BUILD_DIR/$APP_NAME.app"
cp -R "$APP" "$BUILD_DIR/$APP_NAME.app"
APP_OUT="$BUILD_DIR/$APP_NAME.app"

# The bundled CLI tools (folder reference) are copied verbatim and not re-signed
# by xcodebuild. Sign the whole bundle so the nested pandoc/typst/libgmp are
# sealed too. (--deep is fine for ad-hoc; for Developer ID prefer per-binary
# signing, but these are pre-signed and notarization re-validates.)
if [ -z "${DEVELOPER_ID_IDENTITY:-}" ]; then
  echo "==> Deep ad-hoc signing bundle (incl. Resources/Tools)..."
  codesign --force --deep --sign - "$APP_OUT"
fi
echo "==> App: $APP_OUT"

echo "==> Zipping for distribution..."
ZIP="$BUILD_DIR/$APP_NAME.zip"
rm -f "$ZIP"
ditto -c -k --keepParent --sequesterRsrc "$APP_OUT" "$ZIP"
echo "==> Zip: $ZIP"

if [ -n "${NOTARY_PROFILE:-}" ]; then
  echo "==> Notarizing (profile: $NOTARY_PROFILE)..."
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP_OUT"
  rm -f "$ZIP"
  ditto -c -k --keepParent --sequesterRsrc "$APP_OUT" "$ZIP"
  echo "==> Notarized, stapled, and re-zipped."
else
  echo "==> Skipping notarization (set NOTARY_PROFILE to enable)."
fi

echo "Done."
