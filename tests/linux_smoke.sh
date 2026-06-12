#!/bin/bash
# Compile Linux/FPC engine smoke targets without leaving build artifacts in the repo.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTDIR="${OUTDIR:-/tmp/engine5_fpc_engine_smoke}"
FPC="${FPC:-fpc}"
FLAGS=(
  -dSDL
  -dOPENGL
  -MDelphi
  -Sd
  -RIntel
  -Fu.
  -Fuextra
  -Fuextra/sdl2
  -FuBase
  -FuBase/extra
  -Se1
)

cleanup() {
  rm -f "$ROOT/ppas.sh"
}
trap cleanup EXIT

rm -rf "$OUTDIR"
mkdir -p "$OUTDIR"
cd "$ROOT"

compile_only() {
  local target="$1"
  local unit_dir="${2:-}"
  local name
  local log
  local -a extra_flags=()

  name="$(basename "${target%.dpr}")"
  log="$OUTDIR/$name.log"
  if [ -n "$unit_dir" ]; then
    extra_flags+=("-Fu$unit_dir")
  fi

  if "$FPC" "${FLAGS[@]}" "${extra_flags[@]}" -Cn -FU"$OUTDIR" "$target" > "$log" 2>&1; then
    printf '[ ---- ] %s\n' "$target"
  else
    printf '[ FAIL ] %s\n' "$target"
    tail -n 40 "$log"
    return 1
  fi
}

run_test() {
  local target="$1"
  local name
  local log

  name="$(basename "${target%.dpr}")"
  log="$OUTDIR/$name.log"
  if "$FPC" "${FLAGS[@]}" -FU"$OUTDIR" -FE"$OUTDIR" "$target" > "$log" 2>&1 &&
     "$OUTDIR/$name" >> "$log" 2>&1; then
    printf '[ ---- ] %s\n' "$target"
  else
    printf '[ FAIL ] %s\n' "$target"
    tail -n 80 "$log"
    return 1
  fi
}

compile_only tests/PlatformTest.dpr
compile_only tests/OpenGL.dpr
run_test tests/TestStyle.dpr
run_test tests/TestGpuLayout.dpr
run_test tests/TestMesh3D.dpr
run_test tests/TestObjMesh.dpr

printf '\nSUMMARY: Linux/FPC engine smoke targets passed\n'
