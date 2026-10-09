#!/bin/bash
# Build one of the engine's own programs with FPC (Linux, macOS).
# INTERNAL TOOL of the engine repository: demos, tests and tools for development
# and CI. It is not a build system for projects on the engine - such a project
# writes its own build script around build.cfg (see build.cfg).
# Usage: ./build.sh <Name|path> [extra fpc options...]
#   <Name>  - a demo folder name, e.g. SimpleDemo (-> demo/SimpleDemo)
#   <path>  - a program folder or .dpr in the repository, e.g. tools/upgrade5.dpr
# The program is <folder>/<folder>.dpr, or the only .dpr in the folder.
# Options come from build.cfg (engine-wide) and <folder>/build.cfg (if present).
# The executable is written next to the .dpr, units go to <folder>/_fpc.
# Windows counterpart: build.cmd.
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <Name|path> [extra fpc options...]" >&2
  exit 1
fi
ROOT="$(cd "$(dirname "$0")" && pwd)"
target="$1"
shift

if [ -f "$target" ]; then
  dpr="$(cd "$(dirname "$target")" && pwd)/$(basename "$target")"
else
  if [ -d "$target" ]; then
    dir="$(cd "$target" && pwd)"
  elif [ -d "$ROOT/demo/$target" ]; then
    dir="$ROOT/demo/$target"
  else
    echo "ERROR: project not found: $target" >&2
    exit 2
  fi
  dpr="$dir/$(basename "$dir").dpr"
  if [ ! -f "$dpr" ]; then
    dprs=("$dir"/*.dpr)
    if [ ${#dprs[@]} -ne 1 ] || [ ! -f "${dprs[0]}" ]; then
      echo "ERROR: expected $(basename "$dpr") or a single .dpr in $dir" >&2
      exit 2
    fi
    dpr="${dprs[0]}"
  fi
fi
dir="$(dirname "$dpr")"

opts=("@$ROOT/build.cfg")
if [ -f "$dir/build.cfg" ]; then opts+=("@$dir/build.cfg"); fi
mkdir -p "$dir/_fpc"

cd "$ROOT" # build.cfg paths are relative to the repository root
echo "Building $dpr"
fpc "${opts[@]}" -Fu"$dir" -FU"$dir/_fpc" "$@" "$dpr"
