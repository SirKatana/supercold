#!/usr/bin/env python3
"""Renders the helper's lines with Piper (open-source neural TTS) into allies/voice/*.ogg.

  python3 -m venv /tmp/piper && /tmp/piper/bin/pip install piper-tts
  /tmp/piper/bin/python tools/make_voice.py /path/to/en_US-joe-medium.onnx

The voice is en_US-joe-medium from rhasspy/piper-voices. Its dataset is CC0, so the clips
can ship with the game. Lines live in allies/voice_lines.json: edit there, then re-run.
Only missing or changed lines are rendered again."""
import hashlib, json, os, subprocess, sys, wave

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
lines = json.load(open(os.path.join(root, "allies", "voice_lines.json")))
out_dir = os.path.join(root, "allies", "voice")
os.makedirs(out_dir, exist_ok=True)
stamp_path = os.path.join(out_dir, "rendered.json")
stamps = json.load(open(stamp_path)) if os.path.exists(stamp_path) else {}

from piper import PiperVoice
from piper.config import SynthesisConfig
voice = PiperVoice.load(sys.argv[1])
config = SynthesisConfig(length_scale=0.94, noise_scale=0.7, noise_w_scale=0.9)   # a touch brisk, lively

made = 0
for key, text in lines.items():
    digest = hashlib.sha1(text.encode()).hexdigest()[:12]
    ogg = os.path.join(out_dir, key + ".ogg")
    if stamps.get(key) == digest and os.path.exists(ogg):
        continue
    wav = os.path.join(out_dir, key + ".tmp.wav")
    with wave.open(wav, "wb") as f:
        voice.synthesize_wav(text, f, syn_config=config)
    # Trim the silence Piper leaves at both ends so clips can be chained into one sentence.
    trim = "silenceremove=start_periods=1:start_threshold=-45dB,areverse,silenceremove=start_periods=1:start_threshold=-45dB,areverse"
    if key.startswith("guard_"):
        # The security guard is the same voice pitched down and slowed a little, so he is
        # plainly a different, heavier man than the helper.
        trim += ",asetrate=22050*0.84,aresample=22050,atempo=1.10"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", wav, "-af", trim,
        "-ac", "1", "-c:a", "libvorbis", "-q:a", "4", ogg], check=True)
    os.remove(wav)
    stamps[key] = digest
    made += 1
json.dump(stamps, open(stamp_path, "w"), indent=1, sort_keys=True)
print(f"rendered {made}, total {len(lines)}")
