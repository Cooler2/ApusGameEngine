#!/bin/bash

# Assemble a self-contained macOS .app bundle around an already-built engine
# executable: copy the binary and resources, pull in every non-system dynamic
# library it depends on (recursively), rewrite install names to @rpath, emit
# Info.plist and ad-hoc sign nested-first.
#
# This is the dev/CI bundle path (Stage 4 of R-29): dependencies come from the
# host (Homebrew) toolchain, so the resulting .app runs on this machine and as a
# CI artifact but is NOT distributable as-is (Homebrew dylibs carry the host's
# minimum-macOS). For a distributable bundle, point SDL2_LIBDIR / SDL3_LIBDIR /
# REDIST_LIBDIR at libraries built against a controlled MACOSX_DEPLOYMENT_TARGET;
# any bundled dylib whose leaf name matches a file there is substituted from it,
# so the layout produced here is identical — only the dylib source changes.
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

# --- Dependency-walk helpers (bash 3.2: no associative arrays) ----------------
# Directories searched first, by leaf name, before an absolute/@rpath reference.
# A distributable build points these at controlled-deployment-target dylibs and
# gets them substituted transparently for the host's Homebrew copies.
OVERRIDE_DIRS=""
for d in "${SDL2_LIBDIR:-}" "${SDL3_LIBDIR:-}" "${REDIST_LIBDIR:-}"; do
  [ -n "$d" ] && [ -d "$d" ] && OVERRIDE_DIRS="$OVERRIDE_DIRS $d"
done
BREW_LIBDIRS=""
command -v brew >/dev/null 2>&1 && BREW_LIBDIRS="$(brew --prefix 2>/dev/null)/lib"

# Bundled set as a space-padded string of leaf names (membership by substring).
BUNDLED=" "
is_bundled() { case "$BUNDLED" in *" $1 "*) return 0;; *) return 1;; esac; }
mark_bundled() { BUNDLED="$BUNDLED$1 "; }

is_system_path() { case "$1" in /usr/lib/*|/System/*) return 0;; *) return 1;; esac; }

override_for() { # $1=leaf -> path in an override dir, if any
  local leaf="$1" d
  for d in $OVERRIDE_DIRS; do
    [ -f "$d/$leaf" ] && { printf '%s\n' "$d/$leaf"; return; }
  done
}

resolve_dep() { # $1=install-name reference, $2=referring mach-o -> real file
  local ref="$1" from="$2" leaf cand
  leaf="$(basename "$ref")"
  cand="$(override_for "$leaf")"; [ -n "$cand" ] && { printf '%s\n' "$cand"; return; }
  case "$ref" in
    /*) [ -f "$ref" ] && { printf '%s\n' "$ref"; return; };;
    @loader_path/*|@executable_path/*)
      cand="$(dirname "$from")/${ref#@*/}"
      [ -f "$cand" ] && { printf '%s\n' "$cand"; return; };;
  esac
  # @rpath or otherwise unresolved: try the referrer's dir, then the brew prefix.
  for d in "$(dirname "$from")" $BREW_LIBDIRS; do
    [ -f "$d/$leaf" ] && { printf '%s\n' "$d/$leaf"; return; }
  done
}

# Copy every non-system dependency of a mach-o into Frameworks, recursively.
# NB: otool -L reports link-time deps only — anything dlopen'd at runtime (e.g.
# sdl2-compat -> libSDL3) is invisible here and handled as a special case below.
walk_deps() { # $1=mach-o file (already inside the bundle)
  local bin="$1" dep real leaf
  while IFS= read -r dep; do
    [ -z "$dep" ] && continue
    is_system_path "$dep" && continue
    real="$(resolve_dep "$dep" "$bin")"
    if [ -z "$real" ]; then
      echo "  warn: unresolved dependency $dep (from $(basename "$bin"))" >&2
      continue
    fi
    leaf="$(basename "$real")"
    is_bundled "$leaf" && continue
    mark_bundled "$leaf"
    cp "$real" "$FW_DIR/$leaf"; chmod u+w "$FW_DIR/$leaf"
    walk_deps "$FW_DIR/$leaf"
  done < <(otool -L "$bin" | awk 'NR>1{print $1}')
}

resolve_lib() { # $1=env override dir, $2=brew formula, $3=leaf glob
  local dir="$1"
  if [ -z "$dir" ] && command -v brew >/dev/null 2>&1; then
    dir="$(brew --prefix "$2" 2>/dev/null)/lib"
  fi
  local hit
  hit="$(ls "$dir"/$3 2>/dev/null | head -n1 || true)"
  [ -n "$hit" ] && printf '%s\n' "$hit"
}

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

# --- Collect dylibs ----------------------------------------------------------
walk_deps "$MACOS_DIR/$APP_NAME"

# sdl2-compat dlopens libSDL3 at runtime (invisible to otool). If the compat
# shim got bundled, pull SDL3 in explicitly and expose the leaf name it dlopens.
sdl2_bundled="$(ls "$FW_DIR"/libSDL2-*.dylib 2>/dev/null | head -n1 || true)"
if [ -n "$sdl2_bundled" ] && LC_ALL=C grep -qa 'libSDL3' "$sdl2_bundled"; then
  sdl3_src="$(resolve_lib "${SDL3_LIBDIR:-}" sdl3 'libSDL3.0.dylib')"
  [ -z "$sdl3_src" ] && { echo "SDL2 is the sdl2-compat shim but libSDL3.0.dylib was not found (set SDL3_LIBDIR or install sdl3)" >&2; exit 1; }
  sdl3_leaf="$(basename "$sdl3_src")"
  if ! is_bundled "$sdl3_leaf"; then
    mark_bundled "$sdl3_leaf"
    cp "$sdl3_src" "$FW_DIR/$sdl3_leaf"; chmod u+w "$FW_DIR/$sdl3_leaf"
    walk_deps "$FW_DIR/$sdl3_leaf"
  fi
  ln -sf "$sdl3_leaf" "$FW_DIR/libSDL3.dylib"
fi

if [ "$BUNDLED" = " " ]; then
  echo "warn: no non-system dylibs were bundled (statically linked, or deps unresolved)" >&2
fi

# --- Rewrite install names / rpath ------------------------------------------
# Every bundled lib: id -> @rpath/leaf, and each of its bundled deps -> @rpath.
for leaf in $BUNDLED; do
  lib="$FW_DIR/$leaf"
  install_name_tool -id "@rpath/$leaf" "$lib"
  while IFS= read -r dep; do
    dleaf="$(basename "$dep")"
    if is_bundled "$dleaf" && [ "$dep" != "@rpath/$dleaf" ]; then
      install_name_tool -change "$dep" "@rpath/$dleaf" "$lib"
    fi
  done < <(otool -L "$lib" | awk 'NR>1{print $1}')
done

# Executable: point each bundled dep at the bundle copy, ensure the rpath.
while IFS= read -r dep; do
  dleaf="$(basename "$dep")"
  is_bundled "$dleaf" && install_name_tool -change "$dep" "@rpath/$dleaf" "$MACOS_DIR/$APP_NAME"
done < <(otool -L "$MACOS_DIR/$APP_NAME" | awk 'NR>1{print $1}')
if ! otool -l "$MACOS_DIR/$APP_NAME" | grep -q '@executable_path/../Frameworks'; then
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/$APP_NAME"
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
for leaf in $BUNDLED; do
  codesign --force --sign - "$FW_DIR/$leaf"
done
codesign --force --sign - "$MACOS_DIR/$APP_NAME"
codesign --force --sign - "$APP"

codesign --verify --deep --strict "$APP"
echo "Bundle: $APP"
echo "Bundled libraries:"
for leaf in $BUNDLED; do echo "  $leaf"; done
echo "Executable dependencies:"
otool -L "$MACOS_DIR/$APP_NAME" | awk 'NR>1{print "  "$1}'
