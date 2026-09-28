#!/usr/bin/env python3
"""Scores a Scrubbers demo recording: reads the tick barcode the demo stage
draws below its 9:16 band and turns every event into a designed sound.

The aim is satisfying, not busy. Detents are soft wooden tocks, not clicks:
pitched on a pentatonic scale by where the value is (so a scrub up plays a
gentle rising run), panned with the thumb, never more than about fourteen a
second, and nudged in pitch and level so no two are identical. Steps on the
effort bars are longer marimba notes; the mood's words each ring a
glockenspiel note. A few moments get their own sound: a glassy tink as the
glass lens forms, a bloop as the fluid bead rises and drips back, a soft snap
when the elastic lets go, a thump when a control meets its end, and a pop with
a little sparkle when the emoji bursts. Everything sits in a small room and
is mastered quietly.

The barcode (Demo/ScrubbersDemo/DemoStage.swift, TickCode): 24 squares of
13 pt on a 4 pt black frame, centred, its bottom (H - band) / 4 above the
screen's bottom: ten bits of running count, three of kind (1 tick, 2 knock,
3 burst, 4 press, 5 release), four of style (ScrubberStyle order) and four of
place (0-15, where the value was across its range).

usage: sound.py <raw_recording.mp4> <video.mp4> <out.mp4> [--trim T] [--speed S]
       [--scale 3] [--fps 120] [--wav out.wav]
"""
import argparse, math, os, subprocess, tempfile, wave

import numpy as np
from scipy.signal import butter, fftconvolve, sosfilt

ap = argparse.ArgumentParser()
ap.add_argument("raw"); ap.add_argument("video"); ap.add_argument("out")
ap.add_argument("--trim", type=float, default=0.0)
ap.add_argument("--speed", type=float, default=1.0)
ap.add_argument("--scale", type=float, default=3.0)
ap.add_argument("--fps", type=int, default=120)
ap.add_argument("--wav")
a = ap.parse_args()

SR = 48000
STYLES = ["ruler", "glass", "jelly", "elastic", "fluid", "squiggle", "thermostat", "swing", "mood", "tape",
          "effort", "emoji"]
TICK, KNOCK, BURST, PRESS, RELEASE = 1, 2, 3, 4, 5

# ----------------------------------------------------------------------------- reading the barcode
probe = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v", "-show_entries", "stream=width,height",
                        "-of", "csv=p=0", a.raw], capture_output=True, text=True).stdout
W, H = map(int, probe.strip().split(","))
S = a.scale
w_pt, h_pt = W / S, H / S
band = w_pt * 16 / 9
bottom = h_pt - (h_pt - band) / 4
side, pad, bits = 13, 4, 24
top = bottom - (side + pad * 2)
left = (w_pt - (side * bits + pad * 2)) / 2
row_y = int((top + pad + side / 2) * S)
xs = [int((left + pad + side * i + side / 2) * S) for i in range(bits)]
frame_l, frame_r = int((left + 1.5) * S), int((left + side * bits + pad * 2 - 1.5) * S)

cmd = ["ffmpeg", "-v", "error", "-i", a.raw, "-vf", f"fps={a.fps},crop={W}:2:0:{row_y},format=gray",
       "-f", "rawvideo", "-"]
raw = subprocess.run(cmd, capture_output=True, check=True).stdout
frames = len(raw) // (W * 2)
events, last = [], None
for f in range(frames):
    line = raw[f * W * 2:f * W * 2 + W]
    if line[frame_l] > 80 or line[frame_r] > 80:
        continue                      # the stage isn't up, or the app is still zooming in
    b = [1 if line[x] < 128 else 0 for x in xs]
    val = lambda i, n: int("".join(map(str, b[i:i + n])), 2)
    count, kind, style, place = val(0, 10), val(10, 3), val(13, 4), val(17, 4)
    if last is None and count != 0:
        continue                      # wait for a clean zero
    if count != 0 and kind == 0:
        continue                      # a half-drawn barcode
    if last is not None and count != last:
        steps = (count - last) % 1024
        if 0 < steps < 64:
            for k in range(steps):
                events.append(((f + k / steps) / a.fps, kind, style, place))
    last = count

dur = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0",
                            a.video], capture_output=True, text=True).stdout.strip())
events = [((t - a.trim) / a.speed, k, s, p) for t, k, s, p in events]
events = [e for e in events if 0 <= e[0] <= dur]
print(f"{frames} frames scanned, {len(events)} events")

# ----------------------------------------------------------------------------- instruments
def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def lp(x, fc, order=2):
    return sosfilt(butter(order, min(fc, SR * 0.45) / (SR / 2), "low", output="sos"), x)


def bp(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo / (SR / 2), min(hi, SR * 0.45) / (SR / 2)], "band", output="sos"), x)


rng = np.random.default_rng(11)


def modal(freq, dur, partials, mallet=0.0012, noise=0.1, attack=0.0015):
    """A struck bar: a few decaying partials and a soft mallet transient."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for ratio, amp, decay in partials:
        if freq * ratio < SR * 0.45:
            y += amp * np.sin(2 * math.pi * freq * ratio * t) * np.exp(-t / decay)
    y += bp(rng.normal(0, 1, n), 900, 5000) * np.exp(-t / mallet) * noise
    y *= np.minimum(1, t / attack)
    return y


def tock(m, decay=0.085, noise=0.08, cents=0.0):
    """A soft wooden tock: a marimba bar struck lightly and damped fast."""
    return modal(midi_hz(m) * 2 ** (cents / 1200), decay * 4,
                 [(1, 1.0, decay), (3.93, 0.22, decay * 0.25), (9.24, 0.05, decay * 0.08)], noise=noise)


def marimba(m, decay=0.32):
    return modal(midi_hz(m), decay * 3.5, [(1, 1.0, decay), (3.93, 0.28, decay * 0.25), (9.24, 0.07, decay * 0.08)],
                 noise=0.12)


def glock(m, decay=0.9):
    return modal(midi_hz(m), decay * 2.2, [(1, 1.0, decay), (2.76, 0.3, decay * 0.35), (5.4, 0.12, decay * 0.16)],
                 mallet=0.0008, noise=0.05)


def sweep(f0, f1, dur, attack=0.006, decay=None):
    """A round sine that glides from f0 to f1: a bloop."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = f0 * (f1 / f0) ** (np.minimum(t / dur, 1) ** 0.6)
    y = np.sin(2 * math.pi * np.cumsum(f) / SR)
    env = np.minimum(1, t / attack) * np.exp(-t / (decay or dur * 0.45))
    return y * env + 0.35 * np.sin(4 * math.pi * np.cumsum(f) / SR) * env * np.exp(-t / 0.03)


def thump():
    """The end of the road: a low, soft wooden bump."""
    return layer((tock(48, decay=0.07, noise=0.04), 0.9), (tock(60, decay=0.03, noise=0.02), 0.25))


def snap():
    """A rubber band letting go: a quick rising twang, soft."""
    return sweep(150, 330, 0.16, attack=0.003, decay=0.06)


def pop_sparkle():
    """A soft pop, then four glockenspiel sparkles climbing away."""
    out = np.zeros(int(1.4 * SR))
    p = sweep(360, 620, 0.09, attack=0.002, decay=0.035)
    out[:len(p)] += p * 0.9
    for i, m in enumerate([84, 88, 91, 96]):
        g = glock(m, decay=0.45) * (0.34 * 0.82 ** i)
        j = int((0.06 + 0.055 * i) * SR)
        out[j:j + len(g)] += g[:len(out) - j]
    return out


def layer(*parts):
    """Sums (sound, gain) pairs of different lengths."""
    out = np.zeros(max(len(x) for x, _ in parts))
    for x, g in parts:
        out[:len(x)] += x * g
    return out


PENTA = [60, 62, 64, 67, 69, 72, 74, 76, 79, 81, 84, 86, 88, 91, 93, 96]     # C major pentatonic


def penta(place, base, span):
    """Scale degree for a place 0-15 over `span` notes from index `base`."""
    return PENTA[min(base + int(round(place / 15 * (span - 1))), len(PENTA) - 1)]


# ----------------------------------------------------------------------------- the score
# Per style: how dense detent ticks may get (seconds between) and what they sound like.
MIN_GAP = {"ruler": 0.062, "tape": 0.07, "thermostat": 0.07, "fluid": 0.085, "swing": 0.085, "effort": 0.0,
           "mood": 0.0}


def detent(style, place):
    cents = rng.uniform(-8, 8)            # no two tocks quite the same
    if style == "effort":
        return marimba(penta(place, 5, 8)) * 0.55, 0.12
    if style == "mood":
        return glock(penta(place, 5, 9), decay=0.8) * 0.32, 0.35
    if style == "thermostat":
        return tock(penta(place, 2, 8) - 12, decay=0.06, noise=0.12, cents=cents) * 0.62, 0.1
    if style == "tape":
        return tock(penta(place, 4, 7), decay=0.055, cents=cents) * 0.42, 0.08
    if style in ("fluid", "swing"):
        return tock(penta(place, 7, 7), decay=0.05, noise=0.05, cents=cents) * 0.3, 0.1
    return tock(penta(place, 5, 8), decay=0.075, cents=cents) * 0.5, 0.1       # ruler and the rest


def cue_sound(kind, style):
    if kind == KNOCK:
        return thump() * 0.5, 0.12
    if kind == BURST:
        return pop_sparkle() * 0.75, 0.3
    if style == "glass" and kind == PRESS:
        return layer((glock(100, decay=0.6), 0.16), (glock(93, decay=0.8), 0.1)), 0.4
    if style == "glass" and kind == RELEASE:
        return glock(88, decay=0.5) * 0.12, 0.35
    if style == "fluid" and kind == PRESS:
        return sweep(300, 640, 0.14) * 0.3, 0.2
    if style == "fluid" and kind == RELEASE:
        return sweep(560, 280, 0.12) * 0.26, 0.2
    if style == "elastic" and kind == RELEASE:
        return snap() * 0.35, 0.15
    return None, 0


def squish():
    """Jelly bunching up: a low, round bloop that sags as it squashes."""
    return layer((sweep(240, 150, 0.2, attack=0.01, decay=0.09), 1.0), (sweep(480, 300, 0.12, decay=0.04), 0.25))


# Moments the walk itself makes, timed from its press (DemoWalk in the demo
# stage runs to the clock): the jelly is shoved back into a hump 0.45 s in.
SCRIPTED = {"jelly": [(0.45, lambda: squish() * 0.45, 0.2)]}


extra = []
for t, kind, s_, place in events:
    style = STYLES[s_] if s_ < len(STYLES) else "ruler"
    if kind == PRESS:
        for offset, make, send in SCRIPTED.get(style, []):
            extra.append((t + offset, make, send, place))

n = int((dur + 2.0) * SR)
dry = np.zeros((n, 2))
wet_send = np.zeros((n, 2))
last_tick = {}
placed = 0
for t, kind, s, place in events:
    style = STYLES[s] if s < len(STYLES) else "ruler"
    if kind == TICK:
        gap = MIN_GAP.get(style, 0.07)
        if t - last_tick.get(style, -1) < gap:
            continue
        last_tick[style] = t
        x, send = detent(style, place)
    else:
        x, send = cue_sound(kind, style)
        if x is None:
            continue
    x = x * rng.uniform(0.88, 1.0)
    pan = (place / 15 - 0.5) * 0.5
    L, R = math.cos((pan + 1) * math.pi / 4) * math.sqrt(2), math.sin((pan + 1) * math.pi / 4) * math.sqrt(2)
    i = int(t * SR)
    seg = x[:max(0, n - i)]
    dry[i:i + len(seg), 0] += seg * L
    dry[i:i + len(seg), 1] += seg * R
    wet_send[i:i + len(seg), 0] += seg * L * send
    wet_send[i:i + len(seg), 1] += seg * R * send
    placed += 1
for t, make, send, place in extra:
    x = make()
    i = int(t * SR)
    seg = x[:max(0, n - i)]
    for c in range(2):
        dry[i:i + len(seg), c] += seg
        wet_send[i:i + len(seg), c] += seg * send
    placed += 1
print(f"{placed} sounds placed")

# ----------------------------------------------------------------------------- room and master
def room(rt60=0.9, length=1.4, seed=7):
    r = np.random.default_rng(seed)
    m = int(length * SR)
    t = np.arange(m) / SR
    decay = np.exp(-6.9 * t / rt60)
    irs = []
    for _ in range(2):
        ir = lp(r.normal(0, 1, m), 3500) * decay
        ir[:int(0.01 * SR)] *= np.linspace(0, 1, int(0.01 * SR))
        irs.append(ir / np.sqrt((ir ** 2).sum()))
    return irs


irs = room()
mix = dry.copy()
for c in range(2):
    mix[:, c] += 0.6 * fftconvolve(wet_send[:, c] + dry[:, c] * 0.12, irs[c])[:n]
mix[:, 0], mix[:, 1] = lp(mix[:, 0], 7500), lp(mix[:, 1], 7500)
mix = mix[:int(dur * SR)]

tmp = tempfile.mkdtemp()
wav = a.wav or os.path.join(tmp, "score.wav")
peak = np.abs(mix).max() or 1
pcm = np.clip(mix / peak * 0.7, -1, 1)
with wave.open(wav, "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((pcm * 32767).astype("<i2").tobytes())

# Quiet and even: -18 LUFS, peaks under -1.5 dBTP.
subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", a.video, "-i", wav, "-map", "0:v", "-map", "1:a",
                "-c:v", "copy", "-af", "loudnorm=I=-18:TP=-1.5:LRA=11", "-c:a", "aac", "-b:a", "192k",
                "-ar", "48000", "-shortest", a.out], check=True)
print("wrote", a.out)
