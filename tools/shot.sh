#!/usr/bin/env bash
# Renders one frame on a hidden virtual display. Never opens a window on the desktop.
# Usage: tools/shot.sh <out.png> [level] [seconds] [extra game args...]
cd "$(dirname "$0")/.." || exit 2
out=$1; level=${2:-test_room}; after=${3:-1.5}; shift 3 2>/dev/null
xvfb-run -a -s "-screen 0 1280x720x24" godot4 --display-driver x11 --rendering-driver opengl3 --path . -- \
  --god=1 --level="$level" --shot="$out" --shot-after="$after" "$@" 2>&1 | grep -E "SCRIPT ERROR|ERROR:" | head
