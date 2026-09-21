#!/usr/bin/env python3
"""Synthesizes the promo music: promo/cancan.wav, plus promo/timing.json for the choreography.

The tune is the Galop infernal from Offenbach's "Orpheus in the Underworld" (1858), the Can-Can.
The composition is in the public domain, and this recording is made here from sine, square and
noise, so there is nobody to license it from.

The song is rendered straight, then played through the same rate curve the video uses: at the
freeze the tape slows to a crawl (the game's own 0.06), hangs there, and spins back up.
"""
import json, numpy as np, wave, pathlib

SR = 44100
BPM = 152.0
BEAT = 60.0 / BPM            # a quarter note
BAR = BEAT * 2               # 2/4
MIN_SCALE = 0.06

NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
def hz(name: str, octave: int) -> float:
    return 440.0 * 2 ** ((NOTE[name] + 12 * (octave - 4) - 9) / 12)

# The theme, 8 bars of 2/4 in D. (note, octave, length in eighths)
THEME = [("D", 5, 4),
         ("E", 5, 1), ("G", 5, 1), ("F#", 5, 1), ("E", 5, 1),
         ("A", 5, 2), ("A", 5, 2),
         ("A", 5, 1), ("B", 5, 1), ("F#", 5, 1), ("G", 5, 1),
         ("E", 5, 2), ("E", 5, 2),
         ("E", 5, 1), ("G", 5, 1), ("F#", 5, 1), ("E", 5, 1),
         ("D", 5, 1), ("D", 6, 1), ("C#", 6, 1), ("B", 5, 1),
         ("A", 5, 1), ("G", 5, 1), ("F#", 5, 1), ("E", 5, 1)]
CHORDS = ["D", "A", "D", "G", "A", "A", "D", "A"]      # one per bar
TRIAD = {"D": ["D", "F#", "A"], "A": ["A", "C#", "E"], "G": ["G", "B", "D"]}

def env(n: int, attack: float, release: float) -> np.ndarray:
    e = np.ones(n)
    a, r = max(1, int(attack * SR)), max(1, int(release * SR))
    e[:a] = np.linspace(0, 1, a)
    e[-r:] *= np.linspace(1, 0, r)
    return e

def tone(freq: float, seconds: float, kind: str) -> np.ndarray:
    n = int(seconds * SR)
    t = np.arange(n) / SR
    if kind == "square":
        w = np.sign(np.sin(2 * np.pi * freq * t)) * 0.5 + 0.3 * np.sin(2 * np.pi * freq * 2 * t)
    elif kind == "brass":
        w = sum(np.sin(2 * np.pi * freq * k * t) / k for k in range(1, 7))
        w *= 0.5 * (1 + 0.15 * np.sin(2 * np.pi * 5.5 * t))
    elif kind == "bass":
        w = np.sin(2 * np.pi * freq * t) + 0.4 * np.sign(np.sin(2 * np.pi * freq * t))
    else:
        w = np.sin(2 * np.pi * freq * t)
    return w * env(n, 0.006, min(0.05, seconds * 0.4))

def kick() -> np.ndarray:
    n = int(0.22 * SR); t = np.arange(n) / SR
    return np.sin(2 * np.pi * (120 * np.exp(-t * 22) + 45) * t) * np.exp(-t * 14) * 1.4

def snare(rng) -> np.ndarray:
    n = int(0.16 * SR); t = np.arange(n) / SR
    return (rng.standard_normal(n) * 0.8 + np.sin(2 * np.pi * 190 * t)) * np.exp(-t * 26)

def hat(rng, open_: bool = False) -> np.ndarray:
    n = int((0.12 if open_ else 0.04) * SR); t = np.arange(n) / SR
    x = np.diff(rng.standard_normal(n + 1))
    return x * np.exp(-t * (30 if open_ else 90)) * 0.35

def add(buf: np.ndarray, at: float, x: np.ndarray, gain: float = 1.0) -> None:
    i = int(at * SR)
    if i >= len(buf):
        return
    x = x[: len(buf) - i]
    buf[i:i + len(x)] += x * gain

def drums(buf, start: float, bars: int, rng, fill_last: bool = False) -> None:
    for b in range(bars):
        t0 = start + b * BAR
        add(buf, t0, kick(), 0.9); add(buf, t0 + BEAT, kick(), 0.8)
        add(buf, t0 + BEAT / 2, snare(rng), 0.5); add(buf, t0 + BEAT * 1.5, snare(rng), 0.55)
        for e in range(8):
            add(buf, t0 + e * BEAT / 4, hat(rng, e == 7), 0.6)
        if fill_last and b == bars - 1:
            for e in range(8):
                add(buf, t0 + e * BEAT / 4, snare(rng), 0.25 + 0.06 * e)

def theme(buf, start: float, octave_shift: int, lead: str, harmony: bool, gain: float) -> None:
    t = start
    for name, octave, eighths in THEME:
        length = eighths * BEAT / 2
        add(buf, t, tone(hz(name, octave + octave_shift), length * 0.92, lead), gain)
        if harmony:
            add(buf, t, tone(hz(name, octave + octave_shift - 1) * 1.26, length * 0.92, "square"), gain * 0.35)
        t += length
    for b, chord in enumerate(CHORDS):      # oom-pah
        t0 = start + b * BAR
        root, third, fifth = TRIAD[chord]
        add(buf, t0, tone(hz(root, 2), BEAT * 0.8, "bass"), 0.55)
        add(buf, t0 + BEAT, tone(hz(fifth, 2) if fifth != "D" else hz("D", 3), BEAT * 0.8, "bass"), 0.5)
        for off in (BEAT / 2, BEAT * 1.5):
            for n in (root, third, fifth):
                add(buf, t0 + off, tone(hz(n, 4), BEAT * 0.3, "square"), 0.10)

def build():
    rng = np.random.default_rng(7)
    intro, a = 4 * BAR, 8 * BAR
    t_intro, t_a1 = 0.0, intro
    t_a2, t_a3, t_a4 = t_a1 + a, t_a1 + 2 * a, t_a1 + 3 * a
    t_end = t_a1 + 4 * a
    total = t_end + 6.6
    buf = np.zeros(int(total * SR))
    drums(buf, t_intro, 4, rng, fill_last=True)
    for i in range(4):      # a bass note walking up under the intro
        add(buf, t_intro + i * BAR, tone(hz(["D", "E", "F#", "A"][i], 2), BAR * 0.9, "bass"), 0.5)
    theme(buf, t_a1, 0, "square", False, 0.30); drums(buf, t_a1, 8, rng)
    theme(buf, t_a2, 0, "brass", True, 0.22);   drums(buf, t_a2, 8, rng, fill_last=True)
    theme(buf, t_a3, 1, "square", True, 0.24);  drums(buf, t_a3, 8, rng)
    theme(buf, t_a4, 1, "brass", True, 0.20);   drums(buf, t_a4, 8, rng, fill_last=True)
    theme(buf, t_a4, 0, "square", False, 0.16)
    # Cha, cha, CHA.
    for i, g in enumerate((0.8, 0.8, 1.0)):
        at = t_end + i * BEAT * (1.0 if i < 2 else 1.0)
        for n, o in (("D", 3), ("D", 4), ("F#", 4), ("A", 4), ("D", 5)):
            add(buf, at, tone(hz(n, o), BEAT * (0.5 if i < 2 else 3.0), "brass"), 0.16 * g)
        add(buf, at, kick(), 1.0); add(buf, at, snare(rng), 0.7)
    # Under the title card: the first bars again, slowly, on a music box.
    t = t_end + 3.4
    for name, octave, eighths in THEME[:7]:
        length = eighths * BEAT
        add(buf, t, tone(hz(name, octave + 1), length * 1.6, "sine"), 0.22)
        t += length
    song_times = {"intro": t_intro, "a1": t_a1, "a2": t_a2, "a3": t_a3, "a4": t_a4, "end": t_end, "total": total}
    return buf, song_times

def warp(song: np.ndarray, freeze_at: float, down: float, hold: float, up: float):
    """Plays `song` through the rate curve. Returns the output and the curve's key times."""
    out = []
    pos, t, dt = 0.0, 0.0, 1.0 / SR
    n = len(song)
    t_down_end, t_hold_end, t_up_end = freeze_at + down, freeze_at + down + hold, freeze_at + down + hold + up
    # Vectorised in pieces: rate as a function of output time.
    total_out = len(song) / SR + (down + hold + up)      # generous
    tt = np.arange(int(total_out * SR)) / SR
    rate = np.ones_like(tt)
    m = (tt >= freeze_at) & (tt < t_down_end)
    rate[m] = 1.0 + (MIN_SCALE - 1.0) * ((tt[m] - freeze_at) / down) ** 0.6
    rate[(tt >= t_down_end) & (tt < t_hold_end)] = MIN_SCALE
    m = (tt >= t_hold_end) & (tt < t_up_end)
    rate[m] = MIN_SCALE + (1.0 - MIN_SCALE) * ((tt[m] - t_hold_end) / up) ** 2.0
    posn = np.cumsum(rate) / SR * SR
    posn = posn[posn < n - 1]
    i = posn.astype(int); f = posn - i
    warped = song[i] * (1 - f) + song[i + 1] * f
    return warped, {"freeze_at": freeze_at, "down": down, "hold": hold, "up": up}

song, times = build()
freeze_at = times["a3"]      # the tape stops on the downbeat after the second chorus
out, curve = warp(song, freeze_at, 0.9, 3.4, 0.7)
# During the crawl the song is a sub-bass smear. Lift it a little so it is heard.
out = out / np.max(np.abs(out)) * 0.89
pcm = (np.clip(out, -1, 1) * 32767).astype(np.int16)
path = pathlib.Path("promo/out/cancan.wav")
with wave.open(str(path), "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
timing = {"bpm": BPM, "beat": BEAT, "bar": BAR, "min_scale": MIN_SCALE, "song": times, "curve": curve,
          "length": len(out) / SR}
pathlib.Path("promo/timing.json").write_text(json.dumps(timing, indent=1))
print(path, "%.1f s" % (len(out) / SR), json.dumps(times))
