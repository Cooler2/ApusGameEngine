#!/bin/bash

# Assemble a self-contained macOS .app bundle around an already-built engine
# executable: copy the binary, resources and the SDL dylibs, rewrite install
# names to @rpath, emit Info.plist and ad-hoc sign nested-first.
#
# This is the dev/CI bundle path (Stage 4 of R-29): dependencies come from the
# host Homebrew SDL, so the resulting .app runs on this machine and as a CI
# artifact but is NOT distributable as-is (Homebrew dylibs carry the host's
# minimum-macOS). A distributable bundle swaps these for SDL binaries built
# against a controlled MACOSX_DEPLOYMENT_TARGET; the layout produced here is
# identical, so only the dylib source changes.
#
# Usage:
#   tools/make_macos_bundle.sh [--exe PATH] [--name NAME] [--out DIR]
#                              [--resdir DIR] [RESOURCE ...]
# Defaults target SimpleDemo. RESOURCE arguments are files copied into
# Contents/Resources (default: particles.png game.ctl from --resdir).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

APP_NAME="SimpleDemo"
EXE="$ROOT/bin64/SimpleDemo_macos"
OUTDIR="$ROOT/bin64"
RESDIR="$ROOT/demo/SimpleDemo"
BUNDLE_ID="com.apus-software.simpledemo"
MIN_MACOS="${MIN_MACOS:-11.0}"
VERSION="${VERSION:-1.0.0}"
declare -a RESOURCES=()

while [ $# -gt 0 ]; do
  case "$1" in
    --exe) EXE="$2"; shift 2;;
    --name) APP_NAME="$2"; shift 2;;
    --out) OUTDIR="$2"; shift 2;;
    --resdir) RESDIR="$2"; shift 2;;
    --id) BUNDLE_ID="$2"; shift 2;;
    --) shift; break;;
    -*) echo "Unknown option: $1" >&2; exit 2;;
    *) RESOURCES+=("$1"); shift;;
  esac
done
# Trailing positional args (after --) are additional resources.
while [ $# -gt 0 ]; do RESOURCES+=("$1"); shift; done
if [ "${#RESOURCES[@]}" -eq 0 ]; then
  RESOURCES=(particles.png game.ctl)
fi

if [ "$(uname -s)" != "Darwin" ]; then
  echo "make_macos_bundle.sh must be run on macOS" >&2
  exit 2
fi
for tool in install_name_tool codesign otool; do
  command -v "$tool" >/dev/null 2>&1 || { echo "Missing required tool: $tool (install Xcode Command Line Tools)" >&2; exit 2; }
done
if [ ! -x "$EXE" ]; then
  echo "Executable not found: $EXE" >&2
  exit 1
fi

# --- Resolve host SDL dylibs -------------------------------------------------
resolve_lib() { # $1=env override dir, $2=brew formula, $3=leaf glob
  local dir="$1"
  if [ -z "$dir" ] && command -v brew >/dev/null 2>&1; then
    dir="$(brew --prefix "$2" 2>/dev/null)/lib"
  fi
  local hit
  hit="$(ls "$dir"/$3 2>/dev/null | head -n1 || true)"
  [ -n "$hit" ] && printf '%s\n' "$hit"
}

SDL2_SRC="$(resolve_lib "${SDL2_LIBDIR:-}" sdl2 'libSDL2-2.0.0.dylib')"
if [ -z "$SDL2_SRC" ]; then
  echo "Cannot locate libSDL2-2.0.0.dylib (set SDL2_LIBDIR or install sdl2)" >&2
  exit 1
fi

# Homebrew ships "sdl2" as sdl2-compat, an SDL3 shim that dlopens libSDL3 at
# runtime via @loader_path. Classic/official SDL2 is self-contained. Bundle
# libSDL3 only when the SDL2 we picked is actually the compat shim.
SDL3_SRC=""
if LC_ALL=C grep -qa 'libSDL3' "$SDL2_SRC" 2>/dev/null; then
  SDL3_SRC="$(resolve_lib "${SDL3_LIBDIR:-}" sdl3 'libSDL3.0.dylib')"
  if [ -z "$SDL3_SRC" ]; then
    echo "SDL2 is the sdl2-compat shim but libSDL3.0.dylib was not found (set SDL3_LIBDIR or install sdl3)" >&2
    exit 1
  fi
fi

# --- Build the layout --------------------------------------------------------
APP="$OUTDIR/$APP_NAME.app"
CONTENTS="$APP/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RES_OUT="$CONTENTS/Resources"
FW_DIR="$CONTENTS/Frameworks"

rm -rf "$APP"
mkdir -p "$MACOS_DIR" "$RES_OUT" "$FW_DIR"

cp "$EXE" "$MACOS_DIR/$APP_NAME"
chmod u+w "$MACOS_DIR/$APP_NAME"

for res in "${RESOURCES[@]}"; do
  src="$res"
  [ -f "$src" ] || src="$RESDIR/$res"
  if [ ! -f "$src" ]; then
    echo "Resource not found: $res" >&2
    exit 1
  fi
  cp "$src" "$RES_OUT/"
done

sdl2_leaf="$(basename "$SDL2_SRC")"   # libSDL2-2.0.0.dylib
cp "$SDL2_SRC" "$FW_DIR/$sdl2_leaf";  chmod u+w "$FW_DIR/$sdl2_leaf"
if [ -n "$SDL3_SRC" ]; then
  sdl3_leaf="$(basename "$SDL3_SRC")" # libSDL3.0.dylib
  cp "$SDL3_SRC" "$FW_DIR/$sdl3_leaf";  chmod u+w "$FW_DIR/$sdl3_leaf"
  # sdl2-compat dlopens SDL3 via the leaf name "libSDL3.dylib" (@loader_path).
  ln -sf "$sdl3_leaf" "$FW_DIR/libSDL3.dylib"
fi

# --- Rewrite install names / rpath ------------------------------------------
# App links libSDL2 by its absolute Homebrew path; point it at the bundle copy.
sdl2_ref="$(otool -L "$MACOS_DIR/$APP_NAME" | awk '/libSDL2-2\.0\.0\.dylib/{print $1; exit}')"
if [ -n "$sdl2_ref" ]; then
  install_name_tool -change "$sdl2_ref" "@rpath/$sdl2_leaf" "$MACOS_DIR/$APP_NAME"
fi
# Ensure the loader searches Contents/Frameworks.
if ! otool -l "$MACOS_DIR/$APP_NAME" | grep -q '@executable_path/../Frameworks'; then
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/$APP_NAME"
fi
install_name_tool -id "@rpath/$sdl2_leaf" "$FW_DIR/$sdl2_leaf"
if [ -n "$SDL3_SRC" ]; then
  install_name_tool -id "@rpath/$sdl3_leaf" "$FW_DIR/$sdl3_leaf"
fi

# --- Info.plist --------------------------------------------------------------
cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>$APP_NAME</string>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$APP_NAME</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$VERSION</string>
	<key>CFBundleVersion</key>
	<string>$VERSION</string>
	<key>LSMinimumSystemVersion</key>
	<string>$MIN_MACOS</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
PLIST

# --- Ad-hoc sign (nested first, app last) -----------------------------------
[ -n "$SDL3_SRC" ] && codesign --force --sign - "$FW_DIR/$sdl3_leaf"
codesign --force --sign - "$FW_DIR/$sdl2_leaf"
codesign --force --sign - "$MACOS_DIR/$APP_NAME"
codesign --force --sign - "$APP"

codesign --verify --deep --strict "$APP"
echo "Bundle: $APP"
echo "Executable dependencies:"
otool -L "$MACOS_DIR/$APP_NAME" | grep -E 'rpath|SDL' || true
