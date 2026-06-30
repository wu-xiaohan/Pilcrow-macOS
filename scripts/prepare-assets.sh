#!/usr/bin/env bash
#
# Bundles the self-contained CLI helpers (pandoc, typst, and pandoc's libgmp
# dependency) into Pilcrow/Resources/Tools so the shipped .app needs nothing
# installed on the user's machine.
#
# Resources/Tools is git-ignored (pandoc alone is >250 MB, past GitHub's
# 100 MB per-file limit), so this runs from the build scripts and in CI to
# (re)create it. Idempotent: it skips if the tools are already prepared.
#
# Sources are whatever `pandoc`/`typst` are on PATH (i.e. Homebrew):
#   brew install pandoc typst
#
set -euo pipefail
cd "$(dirname "$0")/.."
TOOLS="Pilcrow/Resources/Tools"
mkdir -p "$TOOLS"

# Already prepared? (pandoc present and its libgmp ref already made relative)
if [ -x "$TOOLS/pandoc" ] && [ -x "$TOOLS/typst" ] && [ -f "$TOOLS/libgmp.10.dylib" ] \
   && otool -L "$TOOLS/pandoc" 2>/dev/null | grep -q '@executable_path/libgmp.10.dylib'; then
  echo "==> Tools already prepared (rm -rf $TOOLS to force re-bundle)."
  exit 0
fi

bundle_tool() {  # <name>
  local name="$1" src
  src="$(command -v "$name" || true)"
  if [ -z "$src" ]; then
    echo "ERROR: '$name' not found on PATH. Install it with:  brew install pandoc typst" >&2
    exit 1
  fi
  cp -f "$src" "$TOOLS/$name"
  chmod +x "$TOOLS/$name"
  echo "  + $name  ($src)"
}

echo "==> Bundling CLI tools into $TOOLS ..."
bundle_tool pandoc
bundle_tool typst

# pandoc links one non-system dylib (libgmp); copy it next to the binary and
# repoint the load command at @executable_path so it resolves inside the bundle.
gmp_path="$(otool -L "$TOOLS/pandoc" | awk '/libgmp/{print $1; exit}')"
if [ -n "$gmp_path" ] && [ "${gmp_path#@}" = "$gmp_path" ]; then
  cp -f "$gmp_path" "$TOOLS/libgmp.10.dylib"
  install_name_tool -id @executable_path/libgmp.10.dylib "$TOOLS/libgmp.10.dylib"
  install_name_tool -change "$gmp_path" @executable_path/libgmp.10.dylib "$TOOLS/pandoc"
  echo "  + libgmp.10.dylib  ($gmp_path -> @executable_path)"
fi

# install_name_tool invalidates code signatures; re-sign ad-hoc (sufficient for
# local + GitHub-shared builds; a Developer ID release re-signs via notarization).
[ -f "$TOOLS/libgmp.10.dylib" ] && codesign --force --sign - "$TOOLS/libgmp.10.dylib"
codesign --force --sign - "$TOOLS/pandoc"
codesign --force --sign - "$TOOLS/typst"

# Sanity-check they run self-contained (from inside the Tools dir).
( cd "$TOOLS" && ./pandoc --version >/dev/null && ./typst --version >/dev/null )
echo "==> Tools ready: $(cd "$TOOLS" && ./pandoc --version | head -1), $(cd "$TOOLS" && ./typst --version)"
