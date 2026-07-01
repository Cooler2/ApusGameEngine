#!/bin/bash

# Compile and run one Base test with FPC on macOS arm64.

set -u

cd "$(dirname "$0")"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "test_macos.sh must be run on macOS" >&2
  exit 2
fi

FPC="${FPC:-fpc}"
FLAGS=(-MDelphi -Sd -Ct -CR -Xm -gl -dTIME_OVERRIDE -Fu.. -Fu../extra)
OUTDIR="out_macos"
BINDIR="bin_macos"
LOG="test_results_M64.txt"

TEST="${1:-TestCore}"
if [ ! -f "${TEST}.dpr" ]; then
  TEST="Test${TEST}"
fi
if [ ! -f "${TEST}.dpr" ]; then
  echo "Test source not found: ${TEST}.dpr" >&2
  exit 2
fi

rm -f "$LOG"
rm -rf "$OUTDIR" "$BINDIR"
mkdir -p "$OUTDIR" "$BINDIR"

{
  echo "Testing $TEST (macOS arm64) - $(date)"
  echo
  echo "=== Compiling ==="
} > "$LOG"

"$FPC" "${FLAGS[@]}" -FU"$OUTDIR" -FE"$BINDIR" "${TEST}.dpr" >> "$LOG" 2>&1
status=$?

if [ $status -ne 0 ]; then
  echo "COMPILE FAILED" >> "$LOG"
else
  {
    echo
    echo "=== Running ==="
  } >> "$LOG"
  "./$BINDIR/$TEST" >> "$LOG" 2>&1
  status=$?
  echo "Exit code: $status" >> "$LOG"
fi

cat "$LOG"
exit $status
