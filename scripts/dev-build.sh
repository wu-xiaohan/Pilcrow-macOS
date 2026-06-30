#!/usr/bin/env bash
# Debug build + launch (single command, easy to allowlist / run via `!`).
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

bash scripts/prepare-assets.sh
xcodegen generate >/dev/null
xcodebuild -project Pilcrow.xcodeproj -scheme Pilcrow -configuration Debug \
  -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO | tail -8

APP="$(find "$HOME/Library/Developer/Xcode/DerivedData" -name Pilcrow.app -path '*Build/Products/Debug*' -type d | head -1)"
if [ -n "$APP" ]; then
  open "$APP" /tmp/sample.md
  echo "Launched: $APP"
fi
