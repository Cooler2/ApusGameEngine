#!/bin/bash

# Compile macOS/FPC engine smoke targets without running applications or
# leaving build artifacts in the repository.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTDIR="${OUTDIR:-/tmp/engine5_fpc_macos_smoke}"
FPC="${FPC:-fpc}"
SCOPE="${1:-all}"
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
  -Cr
  -Se1
)

if [ "$(uname -s)" != "Darwin" ]; then
  echo "macos_smoke.sh must be run on macOS" >&2
  exit 2
fi
if [ "$SCOPE" != "all" ] && [ "$SCOPE" != "engine" ] && [ "$SCOPE" != "demos" ]; then
  echo "Usage: $0 [all|engine|demos]" >&2
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

if [ "$SCOPE" = "all" ] || [ "$SCOPE" = "engine" ]; then
  compile_only tests/PlatformTest.dpr
  compile_only tests/OpenGL.dpr
  compile_only tests/TestTextEffects.dpr # needs a GL window: run locally
fi

if [ "$SCOPE" = "all" ] || [ "$SCOPE" = "demos" ]; then
  # Every demo folder with a project file, built the way users build it
  # (build.sh: build.cfg + demo/<Name>/build.cfg), compile-only. Demos that
  # don't compile yet live in demo/legacy/ and are skipped.
  for dir in demo/*/; do
    compgen -G "${dir}*.dpr" > /dev/null || continue
    name="$(basename "$dir")"
    log="$OUTDIR/demo_$name.log"
    mkdir -p "$OUTDIR/demo_$name"
    if "$ROOT/build.sh" "$dir" -Cn -Cr -Se1 -FU"$OUTDIR/demo_$name" > "$log" 2>&1; then
      printf '[ ---- ] %s\n' "$dir"
      ((pass++))
    else
      printf '[ FAIL ] %s\n' "$dir"
      tail -n 50 "$log"
      ((fail++))
      failed+=("$dir")
    fi
  done
fi

printf '\nSUMMARY: %d passed, %d failed\n' "$pass" "$fail"
if [ ${#failed[@]} -gt 0 ]; then
  printf 'Failed targets:\n'
  printf '  %s\n' "${failed[@]}"
fi

[ "$fail" -eq 0 ]
