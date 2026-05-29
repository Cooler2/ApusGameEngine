#!/bin/bash
# ============================================================================
# buildtest.sh - Compile all Base modules to verify they build (Linux/macOS)
# ============================================================================
#
# Usage: bash Base/tests/buildtest.sh
#        or: cd Base/tests && bash buildtest.sh
#
# Modules that cannot build on this platform should be commented out.
# ============================================================================

cd "$(dirname "$0")"

FPC="${FPC:-fpc}"
FLAGS="-MDelphi -Sd -Fu.. -Fu../extra -Cn -Se1"
OUTDIR="out_build"
LOG="buildtest_results.txt"

PASS=0
FAIL=0
FAILLIST=()

rm -rf "$OUTDIR"
mkdir -p "$OUTDIR"

echo "Build Test (64-bit) - $(date)" | tee "$LOG"
echo "==========================================" | tee -a "$LOG"

build() {
  local M="$1"
  local tmpfile="$OUTDIR/$M.tmp"
  if $FPC $FLAGS -FU"$OUTDIR" "../$M.pas" > "$tmpfile" 2>&1; then
    echo "[ ---- ] $M" | tee -a "$LOG"
    ((PASS++))
  else
    echo "[ FAIL ] $M" | tee -a "$LOG"
    cat "$tmpfile" >> "$LOG"
    echo "" >> "$LOG"
    ((FAIL++))
    FAILLIST+=("$M")
  fi
}

# === Level 0: no Apus dependencies ===
build Apus.Types
build Apus.CPU
build Apus.Crypto
build Apus.ADPCM
build Apus.LongMath
build Apus.RegExpr

# === Level 1: Core API ===
build Apus.Core
build Apus.Colors
build Apus.Conv
build Apus.Strings
build Apus.Log

# === Level 2: Utils and platform ===
build Apus.Utils
build Apus.Files
build Apus.Threads
build Apus.HashMaps
build Apus.Compress
build Apus.Geom2D
build Apus.Geom3D
build Apus.Spatial

# === Level 3: Higher-level data structures ===
build Apus.Classes
build Apus.EventMan
build Apus.Lib
build Apus.Tweenings
build Apus.AnimatedValues

# === Level 4: Structs and graphics primitives ===
build Apus.Containers
build Apus.FastGFX
build Apus.VertexLayout
build Apus.Socket

# === Level 5: Images and collections ===
build Apus.Images
build Apus.GfxFilters
build Apus.Regions
build Apus.ProdCons
build Apus.Huffman

# === Level 6: Network and files ===
build Apus.ControlFiles
build Apus.TCP

# === Level 7: High-level network ===
build Apus.HttpRequests
build Apus.GfxFormats

# === Level 8: Text and data ===
build Apus.TextUtils
build Apus.UnicodeFont
build Apus.Translation
build Apus.Database

# === Level 9: Specialized ===
build Apus.HtmlTree
build Apus.FreeTypeFont
build Apus.GlyphCache
build Apus.GeoIP

# === Level 10: Diagnostics and extras ===
build Apus.Logging
# Apus.Profiling is Windows-only (uses unit Windows in implementation)
build Apus.StackTrace
build Apus.Clipboard
build Apus.MemoryLeakUtils
build Apus.Publics
build Apus.RSA
build Apus.SCGI

# === Summary ===
echo "" | tee -a "$LOG"
echo "==========================================" | tee -a "$LOG"
echo "SUMMARY: $PASS passed, $FAIL failed" | tee -a "$LOG"

if [ ${#FAILLIST[@]} -gt 0 ]; then
  echo "Failed modules:" | tee -a "$LOG"
  for M in "${FAILLIST[@]}"; do
    echo "  $M" | tee -a "$LOG"
  done
fi

# exit with error if any module failed
[ $FAIL -eq 0 ]
