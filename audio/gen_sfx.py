#!/usr/bin/env python3
"""Synthesize Ember Hop sound effects (stdlib only). Writes WAVs next to this script."""
import math, os, random, struct, wave

RATE = 22050
OUT = os.path.dirname(os.path.abspath(__file__))
random.seed(7)

def env(t, dur, attack=0.005, release=None):
    release = release if release is not None else dur * 0.6
    if t < attack:
        return t / attack
    return max(0.0, 1.0 - max(0.0, t - (dur - release)) / release)

def tone(freq_fn, dur, wave_fn="sine", vol=0.5, attack=0.005, release=None):
    out, phase = [], 0.0
    for i in range(int(RATE * dur)):
        t = i / RATE
        phase += 2 * math.pi * freq_fn(t) / RATE
        if wave_fn == "sine":
            s = math.sin(phase)
        elif wave_fn == "square":
            s = 0.6 if math.sin(phase) >= 0 else -0.6
        elif wave_fn == "tri":
            s = 2 / math.pi * math.asin(math.sin(phase))
        else:  # noise
            s = random.uniform(-1, 1)
        out.append(s * vol * env(t, dur, attack, release))
    return out

def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]

def concat(*tracks):
    res = []
    for t in tracks:
        res.extend(t)
    return res

def save(name, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    gain = min(1.0, 0.89 / peak)  # about -1 dBFS headroom
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * gain)) * 32767)) for s in samples))
    print(name, f"{len(samples) / RATE:.2f}s")

save("jump.wav", tone(lambda t: 320 + 900 * t / 0.16, 0.16, "square", 0.35))
save("land.wav", tone(lambda t: 140 - 200 * t, 0.09, "noise", 0.25, release=0.08))
save("collect.wav", concat(tone(lambda t: 988, 0.06, "tri", 0.5), tone(lambda t: 1318, 0.14, "tri", 0.5)))
save("stomp.wav", mix(tone(lambda t: 220 - 600 * t, 0.18, "square", 0.4), tone(lambda t: 0, 0.08, "noise", 0.3)))
save("hurt.wav", tone(lambda t: 520 - 1400 * t, 0.32, "square", 0.4, release=0.2))
save("checkpoint.wav", concat(*[tone(lambda t, f=f: f, 0.09, "tri", 0.5) for f in (523, 659, 784)], tone(lambda t: 1046, 0.3, "tri", 0.5)))
save("win.wav", concat(*[tone(lambda t, f=f: f, 0.12, "tri", 0.5) for f in (523, 659, 784, 1046, 784)], tone(lambda t: 1046, 0.6, "tri", 0.5)))
