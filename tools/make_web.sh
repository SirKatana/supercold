#!/usr/bin/env bash
# Builds web/index.html: the whole game in ONE file. Open it in a browser, or host it anywhere.
# web/ is output only. Delete it whenever you like; this script makes it again.
cd "$(dirname "$0")/.." || exit 2
tmp=build/web
rm -rf "$tmp" && mkdir -p "$tmp" web
godot4 --headless --path . --export-release "Web" "$tmp/index.html" 2>&1 | grep -E "^ERROR|Parse Error" | head
[ -f "$tmp/index.wasm" ] || { echo "web export failed"; exit 1; }
python3 tools/inline_web.py "$tmp" web/index.html || exit 1
touch web/.gdignore      # Godot must never import a 65 MB html file
