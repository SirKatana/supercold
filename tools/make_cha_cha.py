#!/usr/bin/env python3
"""Synthesizes the backing track for the house ads: promo/out/cha_cha.wav.

An original cha-cha written here, not a recording of anything: bass tumbao, piano montuno,
guiro, clave, congas and a horn stab, all built out of sine, square, triangle and noise. The
cha-cha-cha lands on beats 4-and-1, which is the whole point of the dance, so the choreography
in promo/ad.gd reads the same grid: 120 BPM, four beats to the bar, 0.5 s a beat.

Writes promo/out/cha_cha.wav (stereo 44.1k) and promo/out/cha_cha.json, which tells the scene
the tempo and how long the loop is.
"""
import json
import pathlib
import wave

import numpy as np

SR = 44100
BPM = 120.0
BEAT = 60.0 / BPM          # 0.5 s
BAR = BEAT * 4             # 2.0 s
BARS = 16                  # 32 seconds, a touch over the 30 the ad runs

NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7,
        "G#": 8, "A": 9, "A#": 10, "B": 11}


def hz(name: str, octave: int) -> float:
    return 440.0 * 2 ** ((NOTE[name] + 12 * (octave - 4) - 9) / 12)


# Two bars of ii-V, two of i: a cha-cha that goes round and round without ever resolving,
# which is what you want behind thirty seconds of somebody being shot.
PROGRESSION = ["Dm", "Dm", "G7", "G7", "Dm", "Dm", "A7", "A7"]
CHORD = {
    "Dm": [("D", 3), ("F", 3), ("A", 3)],
    "G7": [("G", 3), ("B", 3), ("D", 4), ("F", 4)],
    "A7": [("A", 3), ("C#", 4), ("E", 4), ("G", 4)],
}
ROOT = {"Dm": ("D", 2), "G7": ("G", 2), "A7": ("A", 2)}


def envelope(n: int, attack: float, release: float) -> np.ndarray:
    e = np.ones(n)
    a = max(1, int(attack * SR))
    r = max(1, int(release * SR))
    e[:a] = np.linspace(0.0, 1.0, a)
    e[-r:] *= np.linspace(1.0, 0.0, r)
    return e


def tone(freq: float, seconds: float, kind: str) -> np.ndarray:
    n = max(1, int(seconds * SR))
    t = np.arange(n) / SR
    if kind == "piano":
        # A few partials with a hard attack: close enough to a montuno on a tinny upright.
        w = sum(np.sin(2 * np.pi * freq * k * t) * (0.7 ** (k - 1)) for k in range(1, 5))
        w *= np.exp(-t * 7.0)
        return w * envelope(n, 0.002, 0.03)
    if kind == "bass":
        w = np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(2 * np.pi * freq * 2 * t)
        w *= np.exp(-t * 3.2)
        return w * envelope(n, 0.004, 0.05)
    if kind == "horn":
        w = sum(np.sin(2 * np.pi * freq * k * t) / k for k in range(1, 8))
        w *= 0.5 * (1.0 + 0.2 * np.sin(2 * np.pi * 5.0 * t))
        return w * envelope(n, 0.02, 0.08)
    w = np.sin(2 * np.pi * freq * t)
    return w * envelope(n, 0.01, 0.05)


def noise(seconds: float, decay: float, colour: float = 1.0) -> np.ndarray:
    n = max(1, int(seconds * SR))
    rng = np.random.default_rng(7)
    w = rng.standard_normal(n)
    if colour != 1.0:
        # One-pole filter: colour below 1 darkens it, above 1 leaves it bright.
        b = np.clip(colour, 0.05, 1.0)
        out = np.zeros(n)
        acc = 0.0
        for i in range(n):
            acc = acc + b * (w[i] - acc)
            out[i] = acc
        w = out * (1.0 / b)
    return w * np.exp(-np.arange(n) / SR * decay)


def main() -> None:
    out = pathlib.Path(__file__).resolve().parent.parent / "promo" / "out"
    out.mkdir(parents=True, exist_ok=True)
    total = BARS * BAR
    left = np.zeros(int(total * SR) + SR)
    right = np.zeros_like(left)

    def place(buf: np.ndarray, at: float, wave_data: np.ndarray, gain: float) -> None:
        i = int(at * SR)
        n = min(len(wave_data), len(buf) - i)
        if n > 0:
            buf[i:i + n] += wave_data[:n] * gain

    def both(at: float, wave_data: np.ndarray, gain: float, pan: float = 0.0) -> None:
        place(left, at, wave_data, gain * (1.0 - max(0.0, pan)))
        place(right, at, wave_data, gain * (1.0 + min(0.0, pan)))

    for bar_index in range(BARS):
        chord = PROGRESSION[bar_index % len(PROGRESSION)]
        start = bar_index * BAR
        notes = CHORD[chord]
        root_name, root_octave = ROOT[chord]

        # --- bass tumbao: the 1 is left empty, the weight lands on 2-and and 4
        both(start + BEAT * 1.5, tone(hz(root_name, root_octave), BEAT * 0.9, "bass"), 0.55)
        both(start + BEAT * 3.0, tone(hz(notes[-1][0], root_octave + 1), BEAT * 0.5, "bass"), 0.42)
        both(start + BEAT * 3.5, tone(hz(root_name, root_octave), BEAT * 0.9, "bass"), 0.50)

        # --- piano montuno: an off-beat figure that answers the bass
        montuno = [0.5, 1.0, 1.5, 2.5, 3.0, 3.5]
        for k, offset in enumerate(montuno):
            name, octave = notes[k % len(notes)]
            voice = tone(hz(name, octave + 1), BEAT * 0.45, "piano")
            both(start + BEAT * offset, voice, 0.20, pan=0.35 if k % 2 else -0.35)

        # --- the cha-cha-cha itself: beats 4, 4-and, 1 of the next bar, on the guiro and block
        for offset, gain in ((3.0, 0.30), (3.5, 0.30), (4.0, 0.38)):
            both(start + BEAT * offset, noise(0.06, 70.0, 0.55), gain)

        # --- clave 2-3, congas on the off-beats, a shaker keeping the eighths
        for offset in (1.0, 2.5, 4.0 - BEAT):
            both(start + BEAT * offset, noise(0.04, 120.0, 0.9), 0.16)
        for eighth in range(8):
            both(start + BEAT * 0.5 * eighth, noise(0.03, 150.0, 1.0), 0.05)
        for offset in (0.75, 2.75):
            both(start + BEAT * offset, tone(hz("D", 3), 0.09, "sine"), 0.14)

        # --- a horn stab on the first beat of every fourth bar, because it is an advert
        if bar_index % 4 == 0:
            for name, octave in notes:
                both(start, tone(hz(name, octave + 1), BEAT * 0.8, "horn"), 0.13)

    stereo = np.stack([left, right], axis=1)
    peak = float(np.max(np.abs(stereo)))
    if peak > 0.0:
        stereo = stereo / peak * 0.86
    data = (stereo * 32767.0).astype(np.int16)

    with wave.open(str(out / "cha_cha.wav"), "wb") as f:
        f.setnchannels(2)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(data.tobytes())

    (out / "cha_cha.json").write_text(json.dumps({
        "bpm": BPM, "beat": BEAT, "bar": BAR, "bars": BARS, "length": total,
    }, indent=1))
    print("promo/out/cha_cha.wav  %.1f s at %d BPM" % (total, int(BPM)))


if __name__ == "__main__":
    main()
