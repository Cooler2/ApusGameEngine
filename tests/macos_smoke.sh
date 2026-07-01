#!/bin/bash

# Compile macOS/FPC engine smoke targets without running applications or
# leaving build artifacts in the repository.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTDIR="${OUTDIR:-/tmp/engine5_fpc_macos_smoke}"
FPC="${FPC:-fpc}"
FLAGS=(
  -dSDL
  -dOPENGL
  -MDelphi
  -Sd
  -Fu.
  -Fuextra
  -Fuextra/sdl2
  -FuBase
  -FuBase/extra
  -Se1
)

if [ "$(uname -s)" != "Darwin" ]; then
  echo "macos_smoke.sh must be run on macOS" >&2
  exit 2
fi

cleanup() {
  rm -f "$ROOT/ppas.sh" "$ROOT/symbol_order.fpc"
}
trap cleanup EXIT

rm -rf "$OUTDIR"
mkdir -p "$OUTDIR"
cd "$ROOT"

pass=0
fail=0
failed=()

compile_only() {
  local target="$1"
  local unit_dir="${2:-.}"
  local name
  local target_out
  local log

  name="$(basename "${target%.dpr}")"
  target_out="$OUTDIR/$name"
  log="$OUTDIR/$name.log"
  mkdir -p "$target_out"
  if "$FPC" "${FLAGS[@]}" "-Fu$unit_dir" -Cn -FU"$target_out" "$target" > "$log" 2>&1; then
    printf '[ ---- ] %s\n' "$target"
    ((pass++))
  else
    printf '[ FAIL ] %s\n' "$target"
    tail -n 50 "$log"
    ((fail++))
    failed+=("$target")
  fi
}

compile_only tests/PlatformTest.dpr
compile_only tests/OpenGL.dpr

for demo in SimpleDemo Draw2D InputDemo TextDemo Simple3D ShadowMap; do
  compile_only "demo/$demo/$demo.dpr" "demo/$demo"
done

printf '\nSUMMARY: %d passed, %d failed\n' "$pass" "$fail"
if [ ${#failed[@]} -gt 0 ]; then
  printf 'Failed targets:\n'
  printf '  %s\n' "${failed[@]}"
fi

[ "$fail" -eq 0 ]
