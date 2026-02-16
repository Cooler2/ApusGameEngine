#!/bin/bash

# ============================================================================
# test.sh - Compile and run Pascal tests with FPC (64-bit only)
# ============================================================================

# Ensure we are in the script directory
cd "$(dirname "$0")"

# Compiler settings from test.bat [cite: 1, 2]
FPC64="fpc"
FLAGS="-MDelphi -Sd -RIntel -Fu.. -Ct -CR -Xm -gl"
LOG64="test_results_L64.txt"

# Determine which test to run 
if [ -z "$1" ]; then
  TEST="TestCore"
else
  TEST="$1"
  # If file doesn't exist, try adding "Test" prefix 
  if [ ! -f "${TEST}.dpr" ]; then
    TEST="Test${1}"
  fi
fi

# Clean up old results and stale files 
rm -f "$LOG64"
rm -f ../*.ppu ../*.o 2>/dev/null

# === 64-bit Compilation and Execution ===
echo "Testing $TEST (64-bit) - $(date)" > "$LOG64"
echo "" >> "$LOG64"
echo "=== Compiling ===" >> "$LOG64"

# Clean and recreate output directories [cite: 3]
rm -rf out64 bin64
mkdir -p out64 bin64

# Run FPC [cite: 3]
$FPC64 $FLAGS -FU"out64" -FE"bin64" "${TEST}.dpr" >> "$LOG64" 2>&1

if [ $? -ne 0 ]; then
  echo "COMPILE FAILED" >> "$LOG64"
else
  echo "" >> "$LOG64"
  echo "=== Running ===" >> "$LOG64"
  # Execute the compiled binary 
  ./bin64/"$TEST" >> "$LOG64" 2>&1
  echo "Exit code: $?" >> "$LOG64"
fi

# Output results to console [cite: 7]
echo ""
echo "=== 64-bit results ==="
cat "$LOG64"
