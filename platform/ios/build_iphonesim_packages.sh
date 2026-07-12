#!/usr/bin/env bash
# Build the FPC package units the Apus engine needs for the iOS Simulator
# (aarch64-iphonesim) and install them straight into the FPC unit prefix.
#
# Why this exists: the FPC 3.3.1 install ships only the base `rtl` for
# iphonesim - none of the FCL/RTL packages that the device target
# (aarch64-ios) has. The stock package build (`make`/`fpmake`) is broken for
# this cross target: fpmake bootstraps with the system FPC 3.2.2 and dies on an
# fcl-process/pipes checksum mismatch. So we compile each needed unit by hand
# with the cross compiler, in dependency order, dumping the .ppu/.o into the
# per-package folder under the prefix. build.sh's `-Fu<prefix>/units/<arch>/*`
# wildcard then finds them with no extra flags.
#
# Idempotent: skips a package whose sentinel unit is already built unless FORCE=1.
#
# Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
# BSD-3 license (see license.txt). Part of the Apus Game Engine.
set -euo pipefail

FPC_ROOT="${FPC_ROOT:-$HOME/Developer/fpc/3.3.1}"
PPC="$FPC_ROOT/lib/fpc/3.3.1/ppcrossa64"
PKGSRC="$FPC_ROOT/source/packages"
PREFIX="$FPC_ROOT/lib/fpc/3.3.1/units/aarch64-iphonesim"
SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"

[ -x "$PPC" ] || { echo "cross compiler not found: $PPC" >&2; exit 1; }
[ -d "$PKGSRC" ] || { echo "package sources not found: $PKGSRC" >&2; exit 1; }

# Common flags. -Cn stops after the .ppu/.o (no linking). -XR points
# system-header probing at the simulator SDK. Deliberately NO -M/-S: FPC's own
# RTL/FCL package sources declare their {$mode} per unit (mostly objfpc), and
# some - e.g. paszlib - miscompile if a Delphi mode is forced on them.
COMMON=(-Tiphonesim -Paarch64 -Cn "-XR$SDK")

# build_pkg <pkg-folder> <src-dir> <sentinel-unit> <top-unit>...
#   Compiles each <top-unit> into $PREFIX/<pkg-folder>, seeing all already-built
#   packages plus this package's own source dir. FPC auto-pulls in-package deps.
build_pkg() {
  local pkg="$1" srcdir="$2" sentinel="$3"; shift 3
  local out="$PREFIX/$pkg"
  if [ -z "${FORCE:-}" ] && [ -f "$out/$sentinel.ppu" ]; then
    echo "== $pkg: already built ($sentinel.ppu present), skipping"
    return
  fi
  echo "== building $pkg -> $out"
  mkdir -p "$out"
  # See every existing package folder + this package's sources/includes.
  local fu=()
  for d in "$PREFIX"/*/; do fu+=("-Fu${d%/}"); done
  fu+=("-Fu$srcdir" "-Fi$srcdir" "-FU$out")
  local unit
  for unit in "$@"; do
    echo "   -> $unit"
    "$PPC" "${COMMON[@]}" "${fu[@]}" "$srcdir/$unit"
  done
}

# --- dependency order -------------------------------------------------------
# Leaf RTL/FCL packages first, then the ones that consume them.

build_pkg rtl-objpas   "$PKGSRC/rtl-objpas/src/inc"  variants \
  variants.pp dateutils.pp strutils.pp rtti.pp fmtbcd.pp

build_pkg pthreads     "$PKGSRC/pthreads/src"        pthreads \
  pthreads.pp

# fcl-base: assorted RTL-adjacent units the engine pulls (thread sync, etc.).
build_pkg fcl-base     "$PKGSRC/fcl-base/src"        syncobjs \
  syncobjs.pp

build_pkg rtl-generics "$PKGSRC/rtl-generics/src"    generics.defaults \
  generics.defaults.pas generics.collections.pas

# paszlib + pasjpeg feed the fcl-image PNG/JPEG readers. zstream is the PNG
# reader's zlib entry point; it pulls gzio, which needs crc from the hash pkg.
build_pkg hash         "$PKGSRC/hash/src"            crc \
  crc.pas

build_pkg paszlib      "$PKGSRC/paszlib/src"         zstream \
  zstream.pp

# The fcl-image readers reach past jpeglib into the low-level std-API units;
# building both the decompress (jdapistd) and compress (jcapistd) entry points,
# plus the src/dst managers and jcparam, transitively pulls the rest of pasjpeg.
build_pkg pasjpeg      "$PKGSRC/pasjpeg/src"         jdapimin \
  jpeglib.pas jdapimin.pas jdapistd.pas jdatasrc.pas \
  jcapistd.pas jdatadst.pas jcparam.pas

build_pkg fcl-image    "$PKGSRC/fcl-image/src"       fpwritejpeg \
  fpimage.pp fpreadpng.pp fpwritepng.pp fpreadjpeg.pas fpwritejpeg.pas

echo "== done. Installed packages under $PREFIX:"
ls -1 "$PREFIX"
