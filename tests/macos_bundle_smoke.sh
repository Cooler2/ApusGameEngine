#!/bin/bash

# Build SimpleDemo, assemble a macOS .app bundle around it, then run the
# file-based Robot API smoke FROM INSIDE the bundle. Verifies that resource
# resolution, bundled SDL dylibs and the Retina path all work when launched as
# a real .app (Stage 4 of R-29), not just from the build directory.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTDIR="${OUTDIR:-/tmp/engine5_macos_bundle_smoke}"
FPC="${FPC:-fpc}"
APP="$ROOT/bin64/SimpleDemo.app"
EXE="$APP/Contents/MacOS/SimpleDemo"
RES="$APP/Contents/Resources"
ROBOT_IN="$RES/robot_in.txt"
ROBOT_OUT="$RES/robot_out.txt"
# The engine writes logs to the per-platform writable dir, not into the
# read-only bundle Resources. For SimpleDemo (gameTitle "Simple Engine Demo")
# that is ~/Library/Logs/<title>/.
GAME_LOG="$HOME/Library/Logs/Simple Engine Demo/game.log"
SCREENSHOT="$OUTDIR/simpledemo_bundle.png"
BUILD_LOG="$OUTDIR/build.log"
RUN_LOG="$OUTDIR/run.log"
pid=""

if [ "$(uname -s)" != "Darwin" ]; then
  echo "macos_bundle_smoke.sh must be run on macOS" >&2
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

if [ -n "${SDL2_LIBDIR:-}" ]; then
  sdl2LibDir="$SDL2_LIBDIR"
elif command -v brew >/dev/null 2>&1; then
  sdl2LibDir="$(brew --prefix sdl2-compat)/lib"
else
  echo "Set SDL2_LIBDIR or install sdl2-compat with Homebrew" >&2
  exit 2
fi

# --- Build ------------------------------------------------------------------
cd "$ROOT"
if ! "$FPC" \
  -dSDL -dOPENGL -MDelphi -Sd \
  -Fu. -Fuextra -Fuextra/sdl2 -FuBase -FuBase/extra -Fudemo/SimpleDemo \
  "-Fl$sdl2LibDir" "-FU$OUTDIR/units" "-FE$ROOT/bin64" \
  -oSimpleDemo_macos demo/SimpleDemo/SimpleDemo.dpr > "$BUILD_LOG" 2>&1; then
  echo "Build failed" >&2
  tail -n 80 "$BUILD_LOG"
  exit 1
fi

# --- Bundle -----------------------------------------------------------------
if ! "$ROOT/platform/macos/make_bundle.sh" > "$OUTDIR/bundle.log" 2>&1; then
  echo "Bundle assembly failed" >&2
  cat "$OUTDIR/bundle.log"
  exit 1
fi
if ! codesign --verify --deep --strict "$APP" 2>>"$OUTDIR/bundle.log"; then
  echo "Bundle failed code signature verification" >&2
  cat "$OUTDIR/bundle.log"
  exit 1
fi

rm -f "$ROBOT_IN" "$ROBOT_OUT" "$GAME_LOG"

# --- Run from inside the bundle ---------------------------------------------
startEpoch="$(date +%s)"
"$EXE" -ROBOT > "$RUN_LOG" 2>&1 &
pid=$!

for ((i=0;i<80;i++)); do
  if [ -f "$GAME_LOG" ] && [ "$(stat -f %m "$GAME_LOG")" -ge "$startEpoch" ] &&
    grep -q 'All scenes loaded!' "$GAME_LOG"; then
    break
  fi
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "Bundled SimpleDemo exited before loading scenes" >&2
    cat "$RUN_LOG"
    [ -f "$GAME_LOG" ] && tail -n 80 "$GAME_LOG"
    exit 1
  fi
  sleep 0.25
done
if [ ! -f "$GAME_LOG" ] || ! grep -q 'All scenes loaded!' "$GAME_LOG"; then
  echo "Timed out waiting for bundled SimpleDemo scenes" >&2
  [ -f "$GAME_LOG" ] && tail -n 80 "$GAME_LOG"
  exit 1
fi

printf '%s\n' \
  'ID: screenshot-check' \
  'CMD: screenshot' \
  "FILE: $SCREENSHOT" \
  '---' \
  'ID: resize-check' \
  'CMD: window.resize' \
  'W: 1280' \
  'H: 720' \
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
    echo "Bundled SimpleDemo exited before completing Robot API requests" >&2
    tail -n 80 "$GAME_LOG"
    exit 1
  fi
  sleep 0.5
done

if [ ! -f "$ROBOT_OUT" ] || ! grep -q 'ID: exit-check' "$ROBOT_OUT"; then
  echo "Timed out waiting for Robot API response" >&2
  tail -n 80 "$GAME_LOG"
  exit 1
fi

okCount="$(grep -c 'STATUS: OK' "$ROBOT_OUT")"
if [ "$okCount" -ne 4 ] || grep -q 'STATUS: ERROR' "$ROBOT_OUT"; then
  echo "Robot API bundle smoke failed" >&2
  sed -n '1,240p' "$ROBOT_OUT"
  exit 1
fi
if ! grep -q 'SCENE: TMainScene' "$ROBOT_OUT"; then
  echo "Main scene is not active" >&2
  sed -n '1,240p' "$ROBOT_OUT"
  exit 1
fi
# The drawable must track a 1280x720 logical resize scaled by the display's
# actual backing factor. Derive the scale from the response instead of assuming
# 2x: the smoke must pass on a Retina display (scale 2), a plain display
# (scale 1) and any future integer scale, and NSHighResolutionCapable in
# Info.plist must not make the bundle behave differently from the bare binary.
# Robot API responses use CRLF line endings; strip non-digits from the value.
ww="$(awk -F': ' '/^windowWidth: /{gsub(/[^0-9]/,"",$2); print $2; exit}' "$ROBOT_OUT")"
wh="$(awk -F': ' '/^windowHeight: /{gsub(/[^0-9]/,"",$2); print $2; exit}' "$ROBOT_OUT")"
rw="$(awk -F': ' '/^renderWidth: /{gsub(/[^0-9]/,"",$2); print $2; exit}' "$ROBOT_OUT")"
rh="$(awk -F': ' '/^renderHeight: /{gsub(/[^0-9]/,"",$2); print $2; exit}' "$ROBOT_OUT")"
scale=$(( ww / 1280 ))
if [ "$scale" -lt 1 ] || [ $(( 1280 * scale )) -ne "$ww" ] || [ $(( 720 * scale )) -ne "$wh" ] ||
  [ "$rw" != "$ww" ] || [ "$rh" != "$wh" ]; then
  echo "Drawable did not track the 1280x720 resize by an integer backing scale in the bundle" >&2
  echo "window=${ww}x${wh} render=${rw}x${rh} derived scale=${scale}" >&2
  sed -n '1,240p' "$ROBOT_OUT"
  exit 1
fi
echo "Backing scale in bundle: ${scale}x"
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
  echo "Bundled SimpleDemo did not shut down after Engine\\Cmd\\Exit" >&2
  tail -n 80 "$GAME_LOG"
  exit 1
fi

wait "$pid"
runStatus=$?
pid=""
if [ "$runStatus" -ne 0 ]; then
  echo "Bundled SimpleDemo exited with status $runStatus" >&2
  tail -n 80 "$GAME_LOG"
  exit 1
fi

# Capture the summary before removing the robot files below.
summary="$(grep -E 'windowWidth:|windowHeight:|renderWidth:|renderHeight:|SCENE:' "$ROBOT_OUT")"

# The whole point of the writable-path work: a normal run must not write into
# the signed bundle. Drop the test-only robot files we placed in Resources, then
# the seal must still verify — proving the app kept its config (AppDataDir) and
# log (~/Library/Logs) out of Contents/Resources.
rm -f "$ROBOT_IN" "$ROBOT_OUT"
if ! codesign --verify --deep --strict "$APP" 2>>"$OUTDIR/bundle.log"; then
  echo "Bundle seal broken after run: the app wrote into Contents/Resources" >&2
  cat "$OUTDIR/bundle.log"
  exit 1
fi

echo "macOS bundle smoke passed"
echo "Bundle: $APP"
printf '%s\n' "$summary"
