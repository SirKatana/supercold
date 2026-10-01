#!/usr/bin/env bash
# Renders the five house ads offscreen (no window) and muxes each with the cha-cha.
#   tools/make_ads.sh          all five
#   tools/make_ads.sh 3        just the third
# Output: ads/supercold_ad_N.ogv, which is what AdService plays. Theora, because that is the
# only video format Godot decodes.
cd "$(dirname "$0")/.." || exit 2
mkdir -p promo/out ads
python3 tools/make_cha_cha.py || exit 1
want=${1:-}
for n in 1 2 3 4 5; do
  [ -n "$want" ] && [ "$want" != "$n" ] && continue
  echo "--- ad $n"
  rm -f promo/out/ad_raw.avi
  xvfb-run -a -s "-screen 0 1280x720x24" godot4 --display-driver x11 --rendering-driver opengl3 \
    --path . --resolution 1280x720 --write-movie promo/out/ad_raw.avi --fixed-fps 30 \
    res://promo/ad.tscn -- --ad="$n" 2>&1 | grep -E "SCRIPT ERROR|ERROR:" | head
  [ -f promo/out/ad_raw.avi ] || { echo "ad $n: render failed"; exit 1; }
  # 960x540 at 24 fps: five of these ship inside the web build, so size matters more than
  # sharpness. Theora is the only thing Godot decodes.
  ffmpeg -y -loglevel error -i promo/out/ad_raw.avi -i promo/out/cha_cha.wav \
    -map 0:v -map 1:a -t 30 -vf "fps=24,scale=960:540" -c:v libtheora -q:v 5 \
    -c:a libvorbis -q:a 3 "ads/supercold_ad_$n.ogv" && rm -f promo/out/ad_raw.avi
done
ls -la ads/*.ogv
