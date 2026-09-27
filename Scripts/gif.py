#!/usr/bin/env python3
"""Cuts one seamless loop of a style out of a media-stage recording and
encodes it as a GIF.

The media stage (Demo/ScrubbersDemo/MediaStage.swift) plays a style's walk
over and over, gliding back to where it started at the end of each, and
flips a square in the corner (above the crop) at the start of every loop.
This finds the flips, keeps the second whole loop, crops to the control and
writes a palette-optimised GIF.

usage: gif.py <recording.mp4> <out.gif> <control height pt> [--width 720] [--fps 25] [--speed 3]
"""
import argparse, os, shutil, subprocess, sys, tempfile

import numpy as np
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("raw"); ap.add_argument("out"); ap.add_argument("height", type=float)
ap.add_argument("--width", type=int, default=720)
ap.add_argument("--fps", type=int, default=25)
ap.add_argument("--scale", type=float, default=3.0)
ap.add_argument("--speed", type=float, default=1.0, help="the pace it was recorded at (SCRUBBERS_PACE)")
a = ap.parse_args()

S = a.scale
BOX_TOP, MARGIN = 220, 28           # MediaStage.boxTop / .margin, in points
probe = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v", "-show_entries",
                        "stream=width,height", "-of", "csv=p=0", a.raw], capture_output=True, text=True).stdout
W, H = map(int, probe.strip().split(","))

# The flip square: 40 pt at the top-left, 30 pt down. Read one pixel of it
# per frame at 60 fps (two rows, since 4:2:0 can't crop to one).
x, y = int(20 * S), int(50 * S)
cmd = ["ffmpeg", "-v", "error", "-i", a.raw, "-vf", f"fps=60,crop=2:2:{x}:{y},format=gray", "-f", "rawvideo", "-"]
raw = subprocess.run(cmd, capture_output=True, check=True).stdout
states, flips, last = [], [], None
for f in range(len(raw) // 4):
    v = raw[f * 4]
    state = 0 if v < 80 else (1 if v > 170 else None)
    if state is None:
        continue
    if last is not None and state != last:
        flips.append(f / 60)
    last = state
# Launch can flicker the square: a real loop is never shorter than 2.5 s
# of scrubber time, so a flip that soon after the last one is noise.
kept = []
for t in flips:
    if kept and t - kept[-1] < 2.5 * a.speed:
        kept[-1] = t
        continue
    kept.append(t)
if len(kept) < 3:
    sys.exit(f"found {len(kept)} loop starts, need 3: record longer")
start, end = kept[1], kept[2]
print(f"loop {start:.2f}s to {end:.2f}s ({end - start:.2f}s)")

top = int((BOX_TOP - MARGIN) * S)
height = int((a.height + MARGIN * 2) * S) // 2 * 2
# GitHub's page colours: the recording's background, nudged by video
# compression, is snapped back to them so the GIF sits on its theme seamlessly.
PAGE = (13, 17, 23) if os.path.basename(a.out).endswith("-dark.gif") else (255, 255, 255)
out_h = int(round(height * a.width / W / 2)) * 2
with tempfile.TemporaryDirectory() as tmp:
    raw = subprocess.run(["ffmpeg", "-v", "error", "-ss", f"{start:.3f}", "-to", f"{end:.3f}", "-i", a.raw,
                          "-vf", f"setpts=(PTS-STARTPTS)/{a.speed},fps={a.fps},crop={W}:{height}:0:{top},"
                                 f"scale={a.width}:{out_h}:flags=lanczos,format=rgb24",
                          "-f", "rawvideo", "-"], capture_output=True, check=True).stdout
    size = a.width * out_h * 3
    page = np.array(PAGE, dtype=np.int16)
    for i in range(len(raw) // size):
        f = np.frombuffer(raw[i * size:(i + 1) * size], dtype=np.uint8).reshape(out_h, a.width, 3).copy()
        f[np.abs(f.astype(np.int16) - page).max(axis=2) <= 7] = PAGE
        Image.fromarray(f).save(os.path.join(tmp, f"{i:04d}.png"))
    clip = os.path.join(tmp, "%04d.png")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-framerate", str(a.fps), "-i", clip, "-filter_complex",
                    "[0:v]split[a][b];[a]palettegen=max_colors=192:stats_mode=full[p];"
                    "[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle",
                    "-loop", "0", a.out], check=True)
if shutil.which("gifsicle"):
    subprocess.run(["gifsicle", "-O3", "--batch", a.out], check=True)
print(f"{os.path.getsize(a.out) / 1024:.0f} KB  {a.out}")
