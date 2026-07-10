#!/bin/sh
# Source this file before invoking the Android CLI toolchain on macOS.

APUS_ANDROID_TOOLCHAIN_ROOT=${APUS_ANDROID_TOOLCHAIN_ROOT:-"$HOME/Developer/fpc/3.3.1-20523-aarch64-android"}
ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT:-"$HOME/Library/Android/sdk"}
ANDROID_NDK_ROOT=${ANDROID_NDK_ROOT:-"$ANDROID_SDK_ROOT/ndk/27.3.13750724"}
ANDROID_AVD_HOME=${ANDROID_AVD_HOME:-"$HOME/Library/Android/avd"}
JAVA_HOME=${JAVA_HOME:-"/opt/homebrew/opt/openjdk@21"}

export APUS_ANDROID_TOOLCHAIN_ROOT
export ANDROID_SDK_ROOT
export ANDROID_NDK_ROOT
export ANDROID_AVD_HOME
export JAVA_HOME
export FPC_ANDROID="$APUS_ANDROID_TOOLCHAIN_ROOT/lib/fpc/3.3.1/ppcrossa64"
export FPC_ANDROID_BINUTILS="$APUS_ANDROID_TOOLCHAIN_ROOT/binutils"
export FPC_ANDROID_UNITS="$APUS_ANDROID_TOOLCHAIN_ROOT/lib/fpc/3.3.1/units/aarch64-android"
export FPC_ANDROID_LINKER=bfd
export PATH="$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$PATH"
