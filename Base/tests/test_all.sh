#!/bin/bash
# ============================================================================
# test_all.sh - Run deterministic Base regression tests with FPC on Linux
# ============================================================================

cd "$(dirname "$0")"

LOG="test_results_all.txt"
TMP="test_all_results.tmp"
PASS=0
FAIL=0
FAILLIST=()

TESTS=(
  Core
  Conv
  Strings
  Containers
  HashMaps
  Files
  EventMan
  Threads
  Tweenings
  Types
  Geom2D
  Geom3D
  Spatial
  Compress
)

rm -f "$LOG" "$TMP"

echo "Base Tests (Linux 64-bit) - $(date)" | tee "$LOG"
echo "==========================================" | tee -a "$LOG"

for TEST in "${TESTS[@]}"; do
  if bash test.sh "$TEST" > "$TMP" 2>&1; then
    echo "[ ---- ] Test$TEST" | tee -a "$LOG"
    ((PASS++))
  else
    echo "[ FAIL ] Test$TEST" | tee -a "$LOG"
    cat "$TMP" >> "$LOG"
    echo "" >> "$LOG"
    ((FAIL++))
    FAILLIST+=("Test$TEST")
  fi
done

rm -f "$TMP"

echo "" | tee -a "$LOG"
echo "==========================================" | tee -a "$LOG"
echo "SUMMARY: $PASS passed, $FAIL failed" | tee -a "$LOG"

if [ ${#FAILLIST[@]} -gt 0 ]; then
  echo "Failed tests:" | tee -a "$LOG"
  for TEST in "${FAILLIST[@]}"; do
    echo "  $TEST" | tee -a "$LOG"
  done
fi

[ $FAIL -eq 0 ]
