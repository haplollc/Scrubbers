#!/usr/bin/env python3
"""Lay a click on every haptic tick of a Scrubbers demo recording.

simctl recordings are silent. The demo stage (Demo/ScrubbersDemo/DemoStage.swift) writes every tick
into a barcode below the 9:16 band (outside the video): sixteen squares on
a black frame, ten bits of running count, two of kind (1 tick, 2 knock) and
four of the mark it landed on. This reads the barcode frame by frame out of
the raw recording, and wherever the count moves on, lays one synthesised
click per tick (spread across the frame when several landed in it) on the
rendered hero. A burst (kind 3) gets a soft pop instead of a click.

usage: scrub_ticks.py <raw_recording.mp4> <hero.mp4> <out.mp4>
       [--trim T] [--speed S] [--fps F] [--scale 3]
--scale is the screen's pixels per point (3 on current iPhones).
"""
import argparse, math, os, random, struct, subprocess, tempfile, wave

ap = argparse.ArgumentParser()
ap.add_argument("raw"); ap.add_argument("hero"); ap.add_argument("out")
ap.add_argument("--trim", type=float, default=0.0)
ap.add_argument("--speed", type=float, default=1.0)
ap.add_argument("--fps", type=int, default=120)
ap.add_argument("--scale", type=float, default=3.0)
a = ap.parse_args()

probe = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v", "-show_entries",
                        "stream=width,height", "-of", "csv=p=0", a.raw], capture_output=True, text=True).stdout
W_PX, H_PX = map(int, probe.strip().split(","))
W_PT, H_PT = W_PX / a.scale, H_PX / a.scale
band = W_PT * 16 / 9
# The barcode: 16 squares of 20 pt with 4 pt of black frame, centred, its
# bottom (H - band) / 4 above the screen's bottom.
bottom = H_PT - (H_PT - band) / 4
top = bottom - 28
left = (W_PT - 328) / 2
S = a.scale
row_y = int((top + 4 + 10) * S)
xs = [int((left + 4 + 20 * i + 10) * S) for i in range(16)]
frame_x = int((left + 1.5) * S)

W, H = W_PX, H_PX
# Two rows (a one-row crop rounds to nothing under 4:2:0), keep the first.
cmd = ["ffmpeg", "-v", "error", "-i", a.raw, "-vf",
       f"fps={a.fps},crop={W}:2:0:{row_y},format=gray", "-f", "rawvideo", "-"]
raw = subprocess.run(cmd, capture_output=True, check=True).stdout
count = len(raw) // (W * 2)
events, last = [], None
found = 0
frame_right = int((left + 328 - 1.5) * S)
for f in range(count):
    line = raw[f * W * 2:f * W * 2 + W]
    # The black frame on both sides, or the stage isn't up (or the app is
    # still zooming in from its icon, which scrambles the squares).
    if line[frame_x] > 80 or line[frame_right] > 80:
        continue
    found += 1
    bits = [1 if line[x] < 128 else 0 for x in xs]
    n = int("".join(map(str, bits[:10])), 2)
    kind = int("".join(map(str, bits[10:12])), 2)
    mark = int("".join(map(str, bits[12:])), 2)
    # The count starts at zero: wait for a clean zero before listening. A
    # count with no kind is a half-drawn barcode, never a real tick.
    if last is None and n != 0:
        continue
    if n != 0 and kind == 0:
        continue
    if last is not None and n != last:
        steps = (n - last) % 1024
        if 0 < steps < 64:
            for k in range(steps):
                # Several ticks in one frame are spread across it.
                events.append(((f + k / steps) / a.fps, kind, mark))
    last = n

print(f"{count} frames scanned, barcode on {found}, {len(events)} ticks")

def hero_time(t):
    return (t - a.trim) / a.speed

dur = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                            "-of", "csv=p=0", a.hero], capture_output=True, text=True).stdout.strip())
rate = 48000
samples = [0.0] * int(dur * rate + rate // 2)
rng = random.Random(7)
last_t = -1.0
for t, kind, mark in events:
    ht = hero_time(t)
    if ht < 0 or ht > dur:
        continue
    # A ratchet can't click much faster than ~30 times a second and still
    # read as clicks: thin the densest runs.
    if ht - last_t < 0.033 and kind == 1:
        continue
    if kind == 1:
        last_t = ht
    start = int(ht * rate)
    if kind == 3:
        # A pop for the emoji's burst: a quick downward chirp with a soft
        # breathy onset, then a few tiny sparkles.
        for n in range(int(0.16 * rate)):
            tt = n / rate
            f = 900 * math.exp(-tt / 0.05) + 240
            env = min(1, tt / 0.004) * math.exp(-tt / 0.045)
            v = math.sin(2 * math.pi * f * tt) * env * 0.55 + rng.uniform(-1, 1) * math.exp(-tt / 0.006) * 0.12
            if start + n < len(samples):
                samples[start + n] += v
        for delay, freq in [(0.07, 3100), (0.12, 3700), (0.19, 3300), (0.26, 4200)]:
            s0 = start + int(delay * rate)
            for n in range(int(0.05 * rate)):
                tt = n / rate
                if s0 + n < len(samples):
                    samples[s0 + n] += math.sin(2 * math.pi * freq * tt) * math.exp(-tt / 0.012) * 0.07
        continue
    if kind == 2:
        # A knock: lower, rounder, a little longer.
        freq, body_gain, click_gain, length, decay = 420, 0.55, 0.35, 0.05, 0.012
    else:
        # A detent: a few ms of filtered noise under a short pitched body
        # that climbs a little with the mark.
        freq, body_gain, click_gain, length, decay = 1500 + 45 * mark, 0.3, 0.5, 0.03, 0.006
    prev = 0.0
    for n in range(int(length * rate)):
        tt = n / rate
        noise = rng.uniform(-1, 1)
        prev = prev * 0.55 + noise * 0.45
        click = prev * math.exp(-tt / 0.0016) * click_gain
        body = math.sin(2 * math.pi * freq * tt) * math.exp(-tt / decay) * body_gain
        if start + n < len(samples):
            samples[start + n] += click + body

tmp = tempfile.mkdtemp()
wav = os.path.join(tmp, "ticks.wav")
with wave.open(wav, "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
    w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 30000)) for s in samples))

subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", a.hero, "-i", wav, "-map", "0:v", "-map", "1:a",
                "-c:v", "copy", "-c:a", "aac", "-b:a", "160k", "-shortest", a.out], check=True)
print("wrote", a.out)
