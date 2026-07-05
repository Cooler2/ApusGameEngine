#!/bin/bash

# Populate redist/macos/ with an official, self-contained SDL2 dylib for
# building distributable macOS .app bundles (see BUILDING_BUNDLES.md).
#
# Why not Homebrew: `brew install sdl2` is the sdl2-compat shim (needs a second
# libSDL3 at runtime) and every Homebrew dylib carries the build host's
# minimum-macOS. The official SDL2 release is a single self-contained,
# universal (arm64+x86_64) framework with a low deployment target — exactly what
# a redistributable bundle needs, and it removes the SDL3 dependency entirely.
#
# The result is committed to the repo (plain git, loose files) so bundle builds
# are reproducible offline and don't break if an upstream URL moves. This script
# is the "how to update / how to audit" tool: it records provenance in
# redist/macos/SOURCES.txt so the committed binary stays verifiable.
#
# Normalization applied (documented for honesty — the file is NOT byte-identical
# to upstream): the framework binary is extracted, its install id is rewritten to
# @rpath/libSDL2-2.0.0.dylib (the leaf name the engine links against), and it is
# ad-hoc re-signed (required, or it will not load on Apple Silicon after the id
# rewrite invalidates SDL's signature).
#
# Usage: platform/macos/fetch_redist.sh [--version X.Y.Z]

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REDIST="$ROOT/redist/macos"

SDL2_VERSION="2.30.9"
# Pinned SHA-256 of the upstream .dmg. Leave empty to bootstrap: the script then
# prints the downloaded file's hash for you to paste back here and enforce.
SDL2_SHA256="e8f69d97dcab8faf41654d915ee1451d38a155e31c20945e974643d8d776ca9b"

while [ $# -gt 0 ]; do
  case "$1" in
    --version) SDL2_VERSION="$2"; shift 2;;
    -*) echo "Unknown option: $1" >&2; exit 2;;
    *) echo "Unexpected argument: $1" >&2; exit 2;;
  esac
done

if [ "$(uname -s)" != "Darwin" ]; then
  echo "fetch_redist.sh must be run on macOS (needs hdiutil/codesign)" >&2
  exit 2
fi
for tool in curl shasum hdiutil install_name_tool codesign; do
  command -v "$tool" >/dev/null 2>&1 || { echo "Missing required tool: $tool" >&2; exit 2; }
done

DMG="SDL2-$SDL2_VERSION.dmg"
URL="https://github.com/libsdl-org/SDL/releases/download/release-$SDL2_VERSION/$DMG"
LEAF="libSDL2-2.0.0.dylib"

TMP="$(mktemp -d)"
cleanup() {
  [ -n "${MNT:-}" ] && hdiutil detach "$MNT" >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT

echo "Downloading $URL"
curl -fL --retry 3 -o "$TMP/$DMG" "$URL"

got="$(shasum -a 256 "$TMP/$DMG" | awk '{print $1}')"
if [ -z "$SDL2_SHA256" ]; then
  echo "WARNING: no pinned SHA-256. Downloaded .dmg hash is:" >&2
  echo "  $got" >&2
  echo "Paste it into SDL2_SHA256 in this script to enforce provenance on future runs." >&2
elif [ "$got" != "$SDL2_SHA256" ]; then
  echo "SHA-256 mismatch for $DMG" >&2
  echo "  expected: $SDL2_SHA256" >&2
  echo "  got:      $got" >&2
  exit 1
fi

echo "Mounting $DMG"
MNT="$(hdiutil attach -nobrowse -readonly "$TMP/$DMG" | grep -o '/Volumes/[^[:cntrl:]]*' | head -n1)"
[ -n "$MNT" ] || { echo "Failed to mount $DMG" >&2; exit 1; }

FRAMEWORK="$MNT/SDL2.framework"
FW_BIN="$FRAMEWORK/Versions/A/SDL2"
[ -f "$FW_BIN" ] || { echo "SDL2 binary not found inside framework: $FW_BIN" >&2; exit 1; }

mkdir -p "$REDIST/licenses"
cp "$FW_BIN" "$TMP/$LEAF"
chmod u+w "$TMP/$LEAF"

# Locate the SDL license inside the mounted image (path varies by release).
lic="$(find "$MNT" -iname '*license*.txt' 2>/dev/null | head -n1 || true)"
if [ -n "$lic" ]; then
  cp "$lic" "$REDIST/licenses/SDL2-LICENSE.txt"
else
  echo "note: no LICENSE file found in the SDL2 image; SDL2 is under the zlib license (https://www.libsdl.org/license.php)" >&2
fi

hdiutil detach "$MNT" >/dev/null; MNT=""

# Normalize: canonical @rpath id + ad-hoc signature (loadable on arm64).
install_name_tool -id "@rpath/$LEAF" "$TMP/$LEAF"
codesign --force --sign - "$TMP/$LEAF"

mv "$TMP/$LEAF" "$REDIST/$LEAF"
final="$(shasum -a 256 "$REDIST/$LEAF" | awk '{print $1}')"

# Provenance record for the committed (normalized) file.
cat > "$REDIST/SOURCES.txt" <<EOF
# redist/macos provenance — regenerate with platform/macos/fetch_redist.sh

[SDL2]
version        = $SDL2_VERSION
upstream_url   = $URL
upstream_dmg   = $DMG
upstream_sha256 = $got
license        = zlib (licenses/SDL2-LICENSE.txt)
normalization  = extracted SDL2.framework/Versions/A/SDL2;
                 install-id -> @rpath/$LEAF; ad-hoc re-signed
committed_file  = $LEAF
committed_sha256 = $final
EOF

echo
echo "Wrote:"
echo "  $REDIST/$LEAF"
echo "  $REDIST/SOURCES.txt"
[ -f "$REDIST/licenses/SDL2-LICENSE.txt" ] && echo "  $REDIST/licenses/SDL2-LICENSE.txt"
echo
echo "Verify it is self-contained (no libSDL3, no Homebrew paths):"
otool -L "$REDIST/$LEAF" | awk 'NR>1{print "  "$1}'
echo
echo "Build a distributable bundle that substitutes this file with:"
echo "  REDIST_LIBDIR=\"$REDIST\" platform/macos/make_bundle.sh ..."
echo "(REDIST_LIBDIR overrides bundled dylibs by leaf name; unlike SDL2_LIBDIR it"
echo " does not affect the FPC link path, so the dev build still uses Homebrew.)"
