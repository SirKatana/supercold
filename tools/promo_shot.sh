#!/usr/bin/env bash
# One still of the promo at a given second, rendered offscreen. Usage: tools/promo_shot.sh out.png 17.5
cd "$(dirname "$0")/.." || exit 2
xvfb-run -a -s "-screen 0 1280x720x24" godot4 --display-driver x11 --rendering-driver opengl3 --path . \
  --resolution 1280x720 res://promo/dance_party.tscn -- --at="$2" --shot="$1" 2>&1 | grep -E "SCRIPT ERROR|ERROR:" | head
