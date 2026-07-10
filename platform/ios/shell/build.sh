#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SHELL_DIR="$ROOT/platform/ios/shell"
BUILD_DIR="$SHELL_DIR/build"
PASCAL_DIR="$BUILD_DIR/pascal"
FPC_ROOT="${FPC_ROOT:-$HOME/Developer/fpc/3.3.1}"
FPC_VERSION="3.3.1"
FPC_LIB="$FPC_ROOT/lib/fpc/$FPC_VERSION"
FPC="$FPC_LIB/ppcrossa64"

# Target selection: "device" (default) builds for a real iPhone (iphoneos,
# aarch64-ios); "simulator" builds for the iOS Simulator on Apple Silicon
# (iphonesimulator, aarch64-iphonesim). The two differ only in the FPC target
# OS, the unit directory, the Xcode SDK/destination and the vendored SDL2 slice
# — the Pascal source, main.c and the .xcodeproj are identical.
TARGET="${1:-${IOS_TARGET:-device}}"

case "$TARGET" in
  device)
    FPC_OS="ios"
    FPC_DEFS=()
    UNITS_ARCH="aarch64-ios"
    XCODE_SDK="iphoneos"
    XCODE_DEST="generic/platform=iOS"
    PRODUCTS_DIR="Debug-iphoneos"
    SDL_DIR="$ROOT/redist/ios"
    SDL_BINARY_SHA256="ff75fb376c754839b040e58b5f9ef3879446162681a213224e3ec31384fd5793"
    ;;
  simulator|sim)
    FPC_OS="iphonesim"
    # -dIOS: the iphonesim target predefines DARWIN but not IOS, so the SDL2
    # binding would otherwise take its desktop-macOS (CocoaAll) path. Forcing
    # IOS selects the UIKit/iOS binding path, matching a real device build.
    FPC_DEFS=("-dIOS")
    UNITS_ARCH="aarch64-iphonesim"
    XCODE_SDK="iphonesimulator"
    XCODE_DEST="generic/platform=iOS Simulator"
    PRODUCTS_DIR="Debug-iphonesimulator"
    SDL_DIR="$ROOT/redist/ios-simulator"
    # not yet vendored; override via SDL_SIM_SHA256 once the slice is pinned
    SDL_BINARY_SHA256="${SDL_SIM_SHA256:-}"
    ;;
  *)
    echo "Unknown target '$TARGET' (expected: device | simulator)" >&2
    exit 2
    ;;
esac

SDK="$(xcrun --sdk "$XCODE_SDK" --show-sdk-path)"
SDL_FRAMEWORK="$SDL_DIR/SDL2.framework"

test -x "$FPC" || { echo "Missing iOS compiler: $FPC" >&2; exit 1; }
test -d "$FPC_LIB/units/$UNITS_ARCH/rtl" || {
  echo "Missing $UNITS_ARCH RTL under $FPC_LIB/units — build it first" >&2
  exit 1
}
test -d "$SDL_FRAMEWORK" || {
  echo "Missing SDL2 framework: $SDL_FRAMEWORK" >&2
  [ "$TARGET" = "device" ] || \
    echo "  vendor an iphonesimulator SDL2 slice into redist/ios-simulator/ (see Work/R-30 notes)" >&2
  exit 1
}
if [ -n "$SDL_BINARY_SHA256" ]; then
  actualSDLHash="$(shasum -a 256 "$SDL_FRAMEWORK/SDL2" | awk '{print $1}')"
  test "$actualSDLHash" = "$SDL_BINARY_SHA256" || {
    echo "SDL2 binary hash mismatch: $actualSDLHash" >&2
    exit 1
  }
else
  echo "Warning: no pinned SDL2 hash for $TARGET; skipping integrity check" >&2
fi

mkdir -p "$PASCAL_DIR"
(
  cd "$BUILD_DIR"
  "$FPC" "-T$FPC_OS" -Paarch64 -MDelphi -Sd -Cn "${FPC_DEFS[@]}" \
    "-XR$SDK" \
    "-Fu$FPC_LIB/units/$UNITS_ARCH/*" \
    "-Fu$ROOT/extra/sdl2" \
    "-FU$PASCAL_DIR" \
    "-FE$PASCAL_DIR" \
    "$SHELL_DIR/pascal/shell.lpr"
)

ar rcs "$BUILD_DIR/libShellPascal.a" \
  "$PASCAL_DIR"/*.o \
  "$FPC_LIB/units/$UNITS_ARCH/rtl/system.o" \
  "$FPC_LIB/units/$UNITS_ARCH/rtl/sysinit.o" \
  "$FPC_LIB/units/$UNITS_ARCH/rtl/objpas.o"

# FRAMEWORK_SEARCH_PATHS is pinned to redist/ios in the .xcodeproj for the
# device build; override it on the command line for the simulator slice.
xcodebuild \
  -project "$SHELL_DIR/ApusShell.xcodeproj" \
  -scheme ApusShell \
  -configuration Debug \
  -sdk "$XCODE_SDK" \
  -destination "$XCODE_DEST" \
  -derivedDataPath "$SHELL_DIR/DerivedData" \
  FRAMEWORK_SEARCH_PATHS="$SDL_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  build

APP="$SHELL_DIR/DerivedData/Build/Products/$PRODUCTS_DIR/ApusShell.app"
mkdir -p "$APP/Frameworks"
ditto "$SDL_FRAMEWORK" "$APP/Frameworks/SDL2.framework"
cmp "$SDL_FRAMEWORK/SDL2" "$APP/Frameworks/SDL2.framework/SDL2"

echo "Built unsigned shell ($TARGET): $APP"
