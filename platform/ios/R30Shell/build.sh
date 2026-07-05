#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SHELL_DIR="$ROOT/platform/ios/R30Shell"
BUILD_DIR="$SHELL_DIR/build"
PASCAL_DIR="$BUILD_DIR/pascal"
FPC_ROOT="${FPC_ROOT:-$HOME/Developer/fpc/3.3.1}"
FPC_VERSION="3.3.1"
FPC_LIB="$FPC_ROOT/lib/fpc/$FPC_VERSION"
FPC="$FPC_LIB/ppcrossa64"
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
SDL_FRAMEWORK="$ROOT/redist/ios/SDL2.framework"
SDL_BINARY_SHA256="ff75fb376c754839b040e58b5f9ef3879446162681a213224e3ec31384fd5793"

test -x "$FPC" || { echo "Missing iOS compiler: $FPC" >&2; exit 1; }
test -d "$SDL_FRAMEWORK" || { echo "Missing SDL2 framework: $SDL_FRAMEWORK" >&2; exit 1; }
actualSDLHash="$(shasum -a 256 "$SDL_FRAMEWORK/SDL2" | awk '{print $1}')"
test "$actualSDLHash" = "$SDL_BINARY_SHA256" || {
  echo "SDL2 binary hash mismatch: $actualSDLHash" >&2
  exit 1
}

mkdir -p "$PASCAL_DIR"
(
  cd "$BUILD_DIR"
  "$FPC" -Tios -Paarch64 -MDelphi -Sd -Cn \
    "-XR$SDK" \
    "-Fu$FPC_LIB/units/aarch64-ios/*" \
    "-Fu$ROOT/extra/sdl2" \
    "-FU$PASCAL_DIR" \
    "-FE$PASCAL_DIR" \
    "$SHELL_DIR/pascal/r30_pascal.lpr"
)

ar rcs "$BUILD_DIR/libR30Pascal.a" \
  "$PASCAL_DIR"/*.o \
  "$FPC_LIB/units/aarch64-ios/rtl/system.o" \
  "$FPC_LIB/units/aarch64-ios/rtl/sysinit.o" \
  "$FPC_LIB/units/aarch64-ios/rtl/objpas.o"

xcodebuild \
  -project "$SHELL_DIR/R30Shell.xcodeproj" \
  -scheme R30Shell \
  -configuration Debug \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$SHELL_DIR/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  build

APP="$SHELL_DIR/DerivedData/Build/Products/Debug-iphoneos/R30Shell.app"
mkdir -p "$APP/Frameworks"
ditto "$SDL_FRAMEWORK" "$APP/Frameworks/SDL2.framework"
cmp "$SDL_FRAMEWORK/SDL2" "$APP/Frameworks/SDL2.framework/SDL2"

echo "Built unsigned shell: $APP"
