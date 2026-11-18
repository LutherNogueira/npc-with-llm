"""Generates every sound effect and music track of the game by synthesis (no third-party assets).

Usage:  python tools/gen_audio.py
Output: game/audio/sfx/*.wav and game/audio/music/*.wav (mono, 16-bit, 22050 Hz).
The generated files belong to the project; no external license involved.
"""
import math
import os
import random
import struct
import wave

SR = 22050
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "audio")
random.seed(7)
TAU = 2 * math.pi


def n(sec):
    return int(SR * sec)


def save(sub, name, samples, peak=0.8):
    folder = os.path.join(ROOT, sub)
    os.makedirs(folder, exist_ok=True)
    m = max(1e-9, max(abs(s) for s in samples))
    data = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s / m * peak)) * 32767)) for s in samples)
    with wave.open(os.path.join(folder, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


def wavef(shape, ph):
    p = (ph / TAU) % 1.0
    if shape == "sine":
        return math.sin(ph)
    if shape == "tri":
        return 4 * abs(p - 0.5) - 1
    if shape == "square":
        return 1.0 if p < 0.5 else -1.0
    return 2 * p - 1  # saw


def tone(freq, dur, shape="sine", decay=0.0, attack=0.004):
    out = []
    total = n(dur)
    rel = n(0.012)
    for i in range(total):
        t = i / SR
        env = min(1.0, t / attack) * (math.exp(-t * decay) if decay else 1.0)
        if i > total - rel:
            env *= (total - i) / rel
        out.append(wavef(shape, TAU * freq * t) * env)
    return out


def noise(dur):
    return [random.uniform(-1, 1) for _ in range(n(dur))]


def lowpass(x, a):
    y = 0.0
    out = []
    for s in x:
        y += a * (s - y)
        out.append(y)
    return out


def bandpass(x, lo, hi):
    a = lowpass(x, hi)
    b = lowpass(x, lo)
    return [p - q for p, q in zip(a, b)]


def shape_env(x, fn):
    total = len(x)
    return [s * fn(i / total) for i, s in enumerate(x)]


def mix(*tracks, gains=None):
    size = max(len(t) for t in tracks)
    out = [0.0] * size
    for k, t in enumerate(tracks):
        g = gains[k] if gains else 1.0
        for i, s in enumerate(t):
            out[i] += s * g
    return out


def concat(*tracks, gap=0.0):
    out = []
    for t in tracks:
        out.extend(t)
        out.extend([0.0] * n(gap))
    return out


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def swell(p):
    return math.sin(math.pi * p) ** 2


# --------------------------------------------------------------- effects
def make_sfx():
    save("sfx", "click", mix(tone(1000, 0.05, "sine", 70), lowpass(noise(0.05), 0.3), gains=[1.0, 0.15]))
    save("sfx", "verb", tone(660, 0.08, "tri", 40))
    save("sfx", "open", concat(tone(440, 0.08, "tri", 25), tone(660, 0.14, "tri", 18)))
    save("sfx", "close", concat(tone(660, 0.08, "tri", 25), tone(440, 0.14, "tri", 18)))

    for name, f, shape in [("neutral", 220, "tri"), ("mysterious", 140, "tri"), ("amused", 330, "square"),
                           ("annoyed", 180, "saw"), ("curious", 260, "sine")]:
        t = tone(f, 0.055, shape, 45)
        save("sfx", "blip_" + name, lowpass(t, 0.5) if shape in ("square", "saw") else t, peak=0.6)

    save("sfx", "fog", shape_env(lowpass(noise(1.4), 0.06), swell))
    trem = [(1 + math.sin(TAU * 9 * i / SR)) / 2 for i in range(n(1.0))]
    whisper = bandpass(noise(1.0), 0.08, 0.5)
    save("sfx", "whisper", shape_env([w * t for w, t in zip(whisper, trem)], swell))
    save("sfx", "refuse", concat(lowpass(tone(220, 0.15, "saw", 10), 0.15), lowpass(tone(165, 0.32, "saw", 8), 0.15)))
    save("sfx", "wave", shape_env(lowpass(noise(0.4), 0.12), swell))
    save("sfx", "laugh", concat(tone(420, 0.07, "tri", 20), tone(470, 0.07, "tri", 20), tone(520, 0.09, "tri", 20), gap=0.03))

    sweep = []
    ph = 0.0
    for i in range(n(1.2)):
        f = 600 - 500 * (i / n(1.2))
        ph += TAU * f / SR
        sweep.append(math.sin(ph) * math.exp(-i / SR * 2.5))
    save("sfx", "vanish", mix(sweep, shape_env(lowpass(noise(1.2), 0.1), lambda p: math.exp(-p * 3)), gains=[0.6, 0.8]))


# ----------------------------------------------------------------- music
def add_wrapped(buf, start, track, gain=1.0):
    size = len(buf)
    for i, s in enumerate(track):
        buf[(start + i) % size] += s * gain


def pluck(freq, dur=1.6):
    out = []
    for i in range(n(dur)):
        t = i / SR
        v = (math.sin(TAU * freq * t)
             + 0.4 * math.sin(TAU * 2 * freq * t) * math.exp(-6 * t)
             + 0.2 * math.sin(TAU * 3 * freq * t) * math.exp(-9 * t))
        out.append(v * min(1.0, t / 0.003) * math.exp(-2.5 * t))
    return out


def make_music():
    # 8 s ambient drone with a seamless loop (frequencies complete whole cycles).
    dur = 8.0
    drone = []
    for i in range(n(dur)):
        t = i / SR
        lfo = 0.7 + 0.3 * math.sin(TAU * 0.25 * t)
        drone.append((0.5 * math.sin(TAU * 55 * t) + 0.3 * math.sin(TAU * 82.5 * t)
                      + 0.2 * math.sin(TAU * 110.125 * t)) * lfo)
    save("music", "ambient_drone", drone, peak=0.5)

    # Theme: Am - F - C - E, 80 bpm, 24 s. Harp arpeggio + bass + pad.
    beat = 0.75
    chord_len = 8 * beat
    total = n(chord_len * 4)
    buf = [0.0] * total
    chords = [(45, [57, 60, 64, 69]), (41, [57, 60, 65, 69]), (48, [55, 60, 64, 67]), (40, [56, 59, 64, 68])]
    pattern = [0, 1, 2, 3, 2, 1, 2, 1]
    cache = {}
    for c, (bass, notes) in enumerate(chords):
        base = n(c * chord_len)
        for k in range(16):
            m = notes[pattern[k % 8]]
            if m not in cache:
                cache[m] = pluck(midi(m))
            accent = 1.0 if k % 4 == 0 else 0.6
            add_wrapped(buf, base + n(k * beat / 2), cache[m], 0.5 * accent)
        add_wrapped(buf, base, tone(midi(bass), 1.6, "sine", 1.2), 0.9)
        add_wrapped(buf, base + n(4 * beat), tone(midi(bass), 1.4, "sine", 1.4), 0.5)
        for m in notes[:3]:
            pad = shape_env(tone(midi(m - 12), chord_len + 0.5, "tri"), swell)
            add_wrapped(buf, base - n(0.25), pad, 0.18)
    save("music", "theme", buf, peak=0.6)


if __name__ == "__main__":
    make_sfx()
    print("sfx ok")
    make_music()
    print("music ok")
