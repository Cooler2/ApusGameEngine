#!/bin/bash

# Build and run SimpleDemo on macOS, then verify its SDL/OpenGL lifecycle
# through the file-based Robot API.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTDIR="${OUTDIR:-/tmp/engine5_macos_runtime_smoke}"
FPC="${FPC:-fpc}"
DEMO_DIR="$ROOT/demo/SimpleDemo"
EXE="$ROOT/bin64/SimpleDemo_macos"
ROBOT_IN="$DEMO_DIR/robot_in.txt"
ROBOT_OUT="$DEMO_DIR/robot_out.txt"
SCREENSHOT="$OUTDIR/simpledemo.png"
BUILD_LOG="$OUTDIR/build.log"
RUN_LOG="$OUTDIR/run.log"
GAME_LOG="$DEMO_DIR/game.log"
pid=""

if [ "$(uname -s)" != "Darwin" ]; then
  echo "macos_runtime_smoke.sh must be run on macOS" >&2
  exit 2
fi

cleanup() {
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill -TERM "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  fi
  rm -f "$ROBOT_IN" "$ROBOT_OUT" "$ROOT/ppas.sh" "$ROOT/symbol_order.fpc"
}
trap cleanup EXIT

rm -rf "$OUTDIR"
mkdir -p "$OUTDIR/units" "$ROOT/bin64"
rm -f "$EXE" "$ROBOT_IN" "$ROBOT_OUT"

if [ -n "${SDL2_LIBDIR:-}" ]; then
  sdl2LibDir="$SDL2_LIBDIR"
elif command -v brew >/dev/null 2>&1; then
  sdl2LibDir="$(brew --prefix sdl2-compat)/lib"
else
  echo "Set SDL2_LIBDIR or install sdl2-compat with Homebrew" >&2
  exit 2
fi

cd "$ROOT"
if ! "$FPC" \
  -dSDL -dOPENGL -MDelphi -Sd \
  -Fu. -Fuextra -Fuextra/sdl2 -FuBase -FuBase/extra -Fudemo/SimpleDemo \
  "-Fl$sdl2LibDir" "-FU$OUTDIR/units" "-FE$ROOT/bin64" \
  -oSimpleDemo_macos demo/SimpleDemo/SimpleDemo.dpr > "$BUILD_LOG" 2>&1; then
  tail -n 80 "$BUILD_LOG"
  exit 1
fi

cd "$DEMO_DIR"
startEpoch="$(date +%s)"
"$EXE" -ROBOT > "$RUN_LOG" 2>&1 &
pid=$!

for ((i=0;i<80;i++)); do
  if [ -f "$GAME_LOG" ] && [ "$(stat -f %m "$GAME_LOG")" -ge "$startEpoch" ] &&
    grep -q 'All scenes loaded!' "$GAME_LOG"; then
    break
  fi
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "SimpleDemo exited before loading scenes" >&2
    tail -n 80 "$GAME_LOG"
    exit 1
  fi
  sleep 0.25
done
if [ ! -f "$GAME_LOG" ] || [ "$(stat -f %m "$GAME_LOG")" -lt "$startEpoch" ] ||
  ! grep -q 'All scenes loaded!' "$GAME_LOG"; then
  echo "Timed out waiting for SimpleDemo scenes" >&2
  tail -n 80 "$GAME_LOG"
  exit 1
fi

printf '%s\n' \
  'ID: windows-check' \
  'CMD: windows' \
  '---' \
  'ID: screenshot-check' \
  'CMD: screenshot' \
  "FILE: $SCREENSHOT" \
  '---' \
  'ID: resize-check' \
  'CMD: window.resize' \
  'W: 1280' \
  'H: 720' \
  '---' \
  'ID: fps-check' \
  'CMD: fps' \
  'N: 5' \
  '---' \
  'ID: scenes-check' \
  'CMD: scenes' \
  'ACTIVE_ONLY: yes' \
  '---' \
  'ID: exit-check' \
  'CMD: signal' \
  'EVENT: Engine\Cmd\Exit' \
  '===' > "$ROBOT_IN"

for ((i=0;i<60;i++)); do
  if [ -f "$ROBOT_OUT" ] && grep -q 'ID: exit-check' "$ROBOT_OUT"; then
    break
  fi
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "SimpleDemo exited before completing Robot API requests" >&2
    tail -n 80 game.log
    exit 1
  fi
  sleep 0.5
done

if [ ! -f "$ROBOT_OUT" ] || ! grep -q 'ID: exit-check' "$ROBOT_OUT"; then
  echo "Timed out waiting for Robot API response" >&2
  tail -n 80 game.log
  exit 1
fi

okCount="$(grep -c 'STATUS: OK' "$ROBOT_OUT")"
if [ "$okCount" -ne 6 ] || grep -q 'STATUS: ERROR' "$ROBOT_OUT"; then
  echo "Robot API smoke failed" >&2
  sed -n '1,240p' "$ROBOT_OUT"
  exit 1
fi
if ! grep -q 'SCENE: TMainScene' "$ROBOT_OUT"; then
  echo "Main scene is not active" >&2
  sed -n '1,240p' "$ROBOT_OUT"
  exit 1
fi
if ! grep -q '^windowWidth: 2560' "$ROBOT_OUT" ||
  ! grep -q '^windowHeight: 1440' "$ROBOT_OUT" ||
  ! grep -q '^renderWidth: 2560' "$ROBOT_OUT" ||
  ! grep -q '^renderHeight: 1440' "$ROBOT_OUT"; then
  echo "Retina drawable did not track the requested 1280x720 window size" >&2
  sed -n '1,240p' "$ROBOT_OUT"
  exit 1
fi
if [ ! -s "$SCREENSHOT" ]; then
  echo "Robot API did not create a screenshot" >&2
  exit 1
fi

for ((i=0;i<40;i++)); do
  if ! kill -0 "$pid" 2>/dev/null; then
    break
  fi
  sleep 0.25
done
if kill -0 "$pid" 2>/dev/null; then
  echo "SimpleDemo did not shut down after Engine\\Cmd\\Exit" >&2
  tail -n 80 game.log
  exit 1
fi

wait "$pid"
status=$?
pid=""
if [ "$status" -ne 0 ]; then
  echo "SimpleDemo exited with status $status" >&2
  tail -n 80 game.log
  exit 1
fi

echo "macOS runtime smoke passed"
echo "Executable: $EXE"
grep -E 'windowWidth:|windowHeight:|screenDPI:|screenScale:|fps:|SCENE:|width:|height:' "$ROBOT_OUT"
