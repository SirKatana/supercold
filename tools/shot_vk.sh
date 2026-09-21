#!/usr/bin/env bash
# Like tools/shot.sh, but with the real Forward+ renderer on software Vulkan (lavapipe), so the
# picture matches the desktop build: glow, SSAO and all. Slow. Never opens a window.
cd "$(dirname "$0")/.." || exit 2
out=$1; level=${2:-test_room}; after=${3:-1.5}; shift 3 2>/dev/null
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1280x720x24" godot4 --display-driver x11 \
  --rendering-driver vulkan --path . -- --god=1 --level="$level" --shot="$out" --shot-after="$after" "$@" 2>&1 \
  | grep -E "SCRIPT ERROR|ERROR:" | head
