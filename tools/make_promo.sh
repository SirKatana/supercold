#!/usr/bin/env bash
# Renders the promo video offscreen (no window) and muxes it with the music.
#   tools/make_promo.sh            -> promo/out/supercold_promo.mp4
# The song and the timing file come from tools/make_song.py; the scene is promo/dance_party.tscn.
cd "$(dirname "$0")/.." || exit 2
mkdir -p promo/out
python3 tools/make_song.py || exit 1
rm -f promo/out/raw.avi
xvfb-run -a -s "-screen 0 1280x720x24" godot4 --display-driver x11 --rendering-driver opengl3 --path . \
  --resolution 1280x720 --write-movie promo/out/raw.avi --fixed-fps 30 res://promo/dance_party.tscn 2>&1 \
  | grep -E "SCRIPT ERROR|ERROR:" | head
[ -f promo/out/raw.avi ] || { echo "render failed"; exit 1; }
ffmpeg -y -loglevel error -i promo/out/raw.avi -i promo/out/cancan.wav -map 0:v -map 1:a \
  -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -c:a aac -b:a 192k -shortest -movflags +faststart \
  promo/out/supercold_promo.mp4 && rm -f promo/out/raw.avi
# The desk monitors in the game play this: small, 15 fps, and with no audio track at all.
ffmpeg -y -loglevel error -i promo/out/supercold_promo.mp4 -an -vf "fps=15,scale=384:216" -c:v libtheora -q:v 6 \
  world/props/monitor_loop.ogv
ls -la promo/out/supercold_promo.mp4 world/props/monitor_loop.ogv
