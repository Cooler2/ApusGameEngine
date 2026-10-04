#!/bin/bash
# End-to-end smoke of the virtual mouse (Robot API mouse.* commands) on a real engine
# window: builds demo/UI, starts it with -ROBOT and drives it through robot_in.txt.
# Needs a GL 3.3 display (DISPLAY, e.g. Xvfb + Mesa); xdotool (optional) sends real X
# pointer events to check that they are ignored in the virtual mode and work again after.
# Not part of CI (no display there) - run locally:
#   Xvfb :99 -screen 0 1280x1024x24 & DISPLAY=:99 bash tests/robot_mouse_smoke.sh
# A prebuilt demo/UI can be run instead (no build then), e.g. the Win64 one under Wine:
#   APP_DIR=<folder with UI.exe and the DLLs> APP_CMD="wine UI.exe" bash tests/robot_mouse_smoke.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEMO="${APP_DIR:-$ROOT/demo/UI}"
failed=0

if [ -z "${DISPLAY:-}" ]; then
  echo "DISPLAY is not set: start Xvfb first (see the header)" >&2
  exit 2
fi
if [ -z "${APP_CMD:-}" ]; then
  "$ROOT/build.sh" UI > /tmp/robot_mouse_build.log 2>&1 || { tail -20 /tmp/robot_mouse_build.log; exit 1; }
fi

cd "$DEMO"
rm -f robot_in.txt robot_out.txt
${APP_CMD:-./UI} -ROBOT > /tmp/robot_mouse_ui.log 2>&1 &
pid=$!
trap 'kill $pid 2>/dev/null; rm -f "$DEMO/robot_in.txt" "$DEMO/robot_out.txt"' EXIT

# robot "<requests>" -> answer in $answer (requests: lines separated by \n, '---' between)
robot() {
  rm -f robot_out.txt
  printf '%b\n===\n' "$1" > robot_in.txt
  for _ in $(seq 1 100); do
    if [ -f robot_out.txt ]; then
      sleep 0.05
      answer="$(tr -d '\r' < robot_out.txt | sed 's/^\xEF\xBB\xBF//')"
      rm -f robot_out.txt
      return 0
    fi
    sleep 0.1
  done
  answer=''
  return 1
}

# field <id> <key> - value from the last answer
field() {
  awk -v id="$1" -v key="$2" '
    /^ID: / { cur=substr($0,5) }
    cur==id && index($0,key": ")==1 { print substr($0,length(key)+3); exit }' <<< "$answer"
}

check() { # check <description> <actual> <expected>
  if [ "$2" == "$3" ]; then
    printf '[ ok ] %s\n' "$1"
  else
    printf '[FAIL] %s: got "%s", expected "%s"\n' "$1" "$2" "$3"
    failed=1
  fi
}

# center of an element's globalRect (canvas space)
center() {
  robot "ID: e\nCMD: ui.element\nNAME: $1" || return 1
  IFS=, read -r l t r b <<< "$(field e globalRect)"
  cx=$(( (l+r)/2 )); cy=$(( (t+b)/2 ))
}

# wait for an element to appear (async UI changes)
wait_element() {
  for _ in $(seq 1 30); do
    robot "ID: e\nCMD: ui.element\nNAME: $1"
    [ "$(field e STATUS)" == "OK" ] && [ "$(field e visibleEffective)" == "true" ] && return 0
    sleep 0.1
  done
  return 1
}

wait_hidden() {
  for _ in $(seq 1 30); do
    robot "ID: e\nCMD: ui.element\nNAME: $1"
    [ "$(field e STATUS)" != "OK" ] || [ "$(field e visibleEffective)" == "false" ] && return 0
    sleep 0.1
  done
  return 1
}

# the window is up once the robot answers
for _ in $(seq 1 100); do robot "ID: w\nCMD: windows" && break; done
check "engine answers" "$(field w STATUS)" "OK"

center 'Main\Widgets'
bx=$cx; by=$cy

robot "ID: m\nCMD: mouse.mode\nMODE: virtual"
check "virtual mode" "$(field m mode)" "virtual"

if command -v xdotool > /dev/null; then
  wid="$(xdotool search --onlyvisible --name 'UI Demo' | head -1)"
  xdotool mousemove --window "$wid" $bx $by click 1
  sleep 0.5
  robot "ID: s\nCMD: mouse.state"
  check "X pointer does not move the virtual one" "$(field s position)" "outside"
  robot "ID: e\nCMD: ui.element\nNAME: Button1"
  check "X click ignored in the virtual mode" "$(field e STATUS)" "ERROR"
  xdotool mousemove --window "$wid" 1000 700
fi

robot "ID: 1\nCMD: mouse.move\nX: $bx\nY: $by\n---\nID: 2\nCMD: ui.element\nNAME: Main\\\\Widgets"
check "move answered after applying" "$(field 1 state)" "done"
check "hover reported" "$(field 1 under)" 'Main\Widgets'
check "ui.element sees the hover" "$(field 2 underMouse)" "true"

robot "ID: c\nCMD: mouse.click\nX: $bx\nY: $by"
check "click" "$(field c STATUS)" "OK"
wait_element Button1; check "click opened the Widgets page" "$?" "0"

center Button1
robot "ID: d\nCMD: mouse.down\nX: $cx\nY: $cy"
check "button held" "$(field d buttons)" "left"
robot "ID: r\nCMD: mouse.reset"
check "reset releases buttons" "$(field r buttons)" "none"
check "reset moves the pointer out" "$(field r position)" "outside"

center 'Root\Close'
robot "ID: c\nCMD: mouse.click\nX: $cx\nY: $cy"
wait_hidden Button1; check "Back closed the page" "$?" "0"

robot "ID: m\nCMD: mouse.mode\nMODE: physical"
check "physical mode" "$(field m mode)" "physical"
robot "ID: c\nCMD: mouse.click\nX: 1\nY: 1"
check "virtual commands refused" "$(field c STATUS)" "ERROR"

if command -v xdotool > /dev/null; then
  xdotool mousemove --window "$wid" $bx $by sleep 0.3 click 1
  wait_element Button1; check "X click works again in the physical mode" "$?" "0"
fi

# a regular exit (a Wine launcher does not take its program down when killed)
robot "ID: x\nCMD: signal\nEVENT: Engine\\\\Cmd\\\\Exit"
for _ in $(seq 1 50); do kill -0 $pid 2>/dev/null || break; sleep 0.1; done
kill -0 $pid 2>/dev/null && { echo "[FAIL] the app did not exit"; failed=1; }

if [ $failed -ne 0 ]; then
  echo "FAILED (engine log: /tmp/robot_mouse_ui.log)"
  exit 1
fi
echo "SUMMARY: virtual mouse smoke passed"
